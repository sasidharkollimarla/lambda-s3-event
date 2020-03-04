variable "lambda_function_name" {
  default = "s3lambdaevent"
}

locals {
  s3bucketarn = "arn:aws:s3:::tf-s3lambdaevent-mandeep-bucket"
}

resource "aws_s3_bucket" "lambda_trigger_bucket" {
  bucket = "tf-s3lambdaevent-mandeep-bucket"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "s3lambda" {
  filename         = "lambda_function.py.zip"
  function_name    = var.lambda_function_name
  source_code_hash = filebase64sha256("./lambda_function.py.zip")
  runtime          = "python3.6"
  handler          = "lambda_function.lambda_handler"
  memory_size      = "512"
  timeout          = "60"
  role             = aws_iam_role.iam_for_lambda.arn

  depends_on = [aws_iam_role_policy_attachment.lambda_logs, aws_cloudwatch_log_group.cwlogs]
}

resource "aws_cloudwatch_log_group" "cwlogs" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 14
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = local.s3bucketarn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.lambda_trigger_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}