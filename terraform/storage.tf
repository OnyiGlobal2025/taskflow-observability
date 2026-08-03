data "aws_caller_identity" "current" {}

locals {
  # Each LGTM backend gets its own S3 bucket, an IAM role scoped to that bucket,
  # and a Pod Identity association binding its K8s service account to the role.
  # Map key = backend, value = the Kubernetes service account name.
  lgtm_backends = {
    loki  = "loki"
    tempo = "tempo"
    mimir = "mimir"
  }
}

resource "aws_s3_bucket" "lgtm" {
  for_each = local.lgtm_backends

  bucket        = "taskflow-obs-${each.key}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "lgtm" {
  for_each = aws_s3_bucket.lgtm

  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lgtm" {
  for_each = aws_s3_bucket.lgtm

  bucket = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Trust policy: allow the EKS Pod Identity service to assume these roles
data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lgtm" {
  for_each = local.lgtm_backends

  name               = "taskflow-obs-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
}

# Per-backend S3 permissions, scoped to that backend's bucket only
data "aws_iam_policy_document" "lgtm_s3" {
  for_each = local.lgtm_backends

  statement {
    sid       = "ListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.lgtm[each.key].arn]
  }

  statement {
    sid    = "ObjectAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.lgtm[each.key].arn}/*"]
  }
}

resource "aws_iam_role_policy" "lgtm_s3" {
  for_each = local.lgtm_backends

  name   = "s3-access"
  role   = aws_iam_role.lgtm[each.key].id
  policy = data.aws_iam_policy_document.lgtm_s3[each.key].json
}

# Bind each backend's K8s service account to its IAM role.
# Namespace and SA are referenced by name; they need not exist yet.
resource "aws_eks_pod_identity_association" "lgtm" {
  for_each = local.lgtm_backends

  cluster_name    = module.eks.cluster_name
  namespace       = var.observability_namespace
  service_account = each.value
  role_arn        = aws_iam_role.lgtm[each.key].arn
}
