{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 24,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/CloudFront", "5xxErrorRate", "DistributionId", "${distribution_id}", { "label": "5xxErrorRate" } ]
        ],
        "period": 300,
        "stat": "Average",
        "title": "CloudFront 5xx Error Rate"
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/CloudFront", "Requests", "DistributionId", "${distribution_id}", { "label": "Requests" } ]
        ],
        "period": 300,
        "stat": "Sum",
        "title": "CloudFront Requests"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/S3", "4xxErrors", "BucketName", "${primary_bucket}", "StorageType", "AllStorageTypes", { "label": "S3 Primary 4xx" } ],
          [ ".", "5xxErrors", ".", "${primary_bucket}", ".", "AllStorageTypes", { "label": "S3 Primary 5xx" } ]
        ],
        "period": 300,
        "stat": "Sum",
        "title": "S3 Primary Errors"
      }
    },
    {
      "type": "text",
      "x": 0,
      "y": 12,
      "width": 24,
      "height": 2,
      "properties": {
        "markdown": "CloudFront Distribution: **${distribution_id}**  \nPrimary bucket: **${primary_bucket}**  \nSecondary bucket: **${secondary_bucket}**"
      }
    }
  ]
}
