/*
 * This file contains configurations for grafana provider authentication.
 * And creates a folder in grafana workspace and configures a dashboard in that folder.
 * This should perform after grafana agent starts ingesting metrices from the EKS
 */

provider "grafana" {
  url  = "https://${var.grafana_endpoint}/"
  auth = var.admin_api_key
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

resource "grafana_data_source" "amp" {
  name                 = "Prometheus ${var.environment} ${var.region} ${var.prometheus_workspace_id}"
  type                 = "prometheus"
  url                  = "${var.prometheus_endpoint}"
  access_mode          = "proxy"
  basic_auth_enabled   = false
  
  json_data_encoded = jsonencode({
    httpMethod         = "GET"
    sigV4Auth          = true
    sigV4AuthType      = "IAM"
    sigV4Region        = var.region
    manageAlerts       = true
  })
}

resource "grafana_data_source" "loki" {
  name                     = "Loki ${var.environment} ${var.region}"
  type                     = "loki"
  url                      = "https://loki-${var.environment}-${var.region}.services.bluebrix.healthcare/"
  access_mode              = "proxy"  # or "direct" depending on your setup
  basic_auth_enabled       = true
  basic_auth_username      = var.loki_username
  secure_json_data_encoded = jsonencode({
    basicAuthPassword = var.loki_password
  })
  http_headers             = {
    X-Scope-OrgID = var.environment
  }
  lifecycle {
    ignore_changes = [json_data_encoded, http_headers]
  }
}

resource "grafana_data_source" "tempo" {
  name                     = "Tempo ${var.environment} ${var.region}"
  type                     = "tempo"
  url                      = "https://tempo-${var.environment}-${var.region}.services.bluebrix.healthcare/"
  access_mode              = "proxy"  # or "direct" depending on your setup
  basic_auth_enabled       = true
  basic_auth_username      = var.tempo_username
  secure_json_data_encoded = jsonencode({
    basicAuthPassword = var.tempo_password
  })
  lifecycle {
    ignore_changes = [json_data_encoded, http_headers]
  }
}

resource "grafana_data_source_config" "loki" {
  uid = grafana_data_source.loki.uid

  json_data_encoded = jsonencode({
    derivedFields = [
      {
        datasourceUid = grafana_data_source.tempo.uid
        matcherRegex  = "[tT]race_?[iI][dD]\"?[:=]\"?(\\w+)"
        matcherType   = "regex"
        name          = "traceID"
        url           = "$${__value.raw}"
      }
    ]
  })
}

resource "grafana_data_source_config" "tempo" {
  uid = grafana_data_source.tempo.uid

  json_data_encoded = jsonencode({
    tracesToLogsV2 = {
      datasourceUid      = grafana_data_source.loki.uid
      spanStartTimeShift = "-5m"
      spanEndTimeShift   = "5m"
      filterBySpanID     = false
      filterByTraceID    = false
      customQuery        = false
      tags = [
        {
          key: "service.name", value: "container"
        }
      ]
    }
    tracesToMetrics = {
      datasourceUid      = grafana_data_source.amp.uid
      spanStartTimeShift = "-2m"
      spanEndTimeShift   = "2m"
      tags = [
        {
          key: "service.name", value: "server"
        }
      ]
      queries = [
        {
          name  = "Requests Rate"
          query = "sum by (client, server)(rate(traces_service_graph_request_total{$__tags}[$__rate_interval]))"
        },
        {
          name  = "Error Rate"
          query = "sum by (client, server)(rate(traces_service_graph_request_failed_total{$__tags}[$__rate_interval]))"
        }
      ]
    }
    serviceMap = {
      datasourceUid = grafana_data_source.amp.uid
    }
    nodeGraph = {
      enabled = true
    }
    lokiSearch = {
      datasourceUid = grafana_data_source.loki.uid
    }
    tlsSkipVerify = true
  })
}

resource "grafana_folder" "cluster_metrics" {
  title = "Cluster Metrics"
}

resource "grafana_folder" "cluster_logs" {
  title = "Cluster Logs"
}

data "local_file" "metrics_dashboard" {
  filename = var.cluster_metrics_config
}

data "local_file" "logs_dashboard" {
  filename = var.cluster_logs_config
}

locals {
  metrics_dashboard_json = replace(replace(replace(data.local_file.metrics_dashboard.content, "datasourceNAME", grafana_data_source.amp.name), "environmentNAME", var.environment), "regionNAME", var.region)
  logs_dashboard_json    = replace(replace(replace(data.local_file.logs_dashboard.content, "datasourceNAME", grafana_data_source.loki.name), "environmentNAME", var.environment), "regionNAME", var.region)
}

resource "grafana_dashboard" "cluster_metrics" {
  folder       = grafana_folder.cluster_metrics.id
  config_json  = local.metrics_dashboard_json
  depends_on   = [grafana_data_source.amp]
}

resource "grafana_dashboard" "cluster_logs" {
  folder       = grafana_folder.cluster_logs.id
  config_json  = local.logs_dashboard_json
  depends_on   = [grafana_data_source.loki]
}

resource "grafana_dashboard_permission" "collectionPermissionMetrics" {
  dashboard_uid = grafana_dashboard.cluster_metrics.uid
  permissions {
    role       = "Editor"
    permission = "Edit"
  }
  permissions {
    role       = "Viewer"
    permission = "View"
  }
}

resource "grafana_dashboard_permission" "collectionPermissionLogs" {
  dashboard_uid = grafana_dashboard.cluster_logs.uid
  permissions {
    role       = "Editor"
    permission = "Edit"
  }
  permissions {
    role       = "Viewer"
    permission = "View"
  }
}

resource "grafana_message_template" "slack_combined_template" {
  name     = "slack"

  template = <<-EOT
  {{ define "slack.tittle" }}
  {{ len .Alerts.Firing }} firing alerts, {{ len .Alerts.Resolved }} resolved alerts
  {{ end }}

  {{ define "slack.print_alert" -}}
  [{{.Status}}] {{ .Labels.alertname }}
  Labels:
  {{ range .Labels.SortedPairs -}}
  - {{ .Name }}: {{ .Value }}
  {{ end -}}
  {{ if .Annotations -}}
  Annotations:
  {{ range .Annotations.SortedPairs -}}
  - {{ .Name }}: {{ .Value }}
  {{ end -}}
  {{ end -}}
  {{ if .DashboardURL -}}
    Go to dashboard: {{ .DashboardURL }}
  {{- end }}
  {{- end }}

  {{ define "slack.message" -}}
  {{ if .Alerts.Firing -}}
  {{ len .Alerts.Firing }} firing alerts:
  {{ range .Alerts.Firing }}
  {{ template "slack.print_alert" . }}
  {{ end -}}
  {{ end }}
  {{ if .Alerts.Resolved -}}
  {{ len .Alerts.Resolved }} resolved alerts:
  {{ range .Alerts.Resolved }}
  {{ template "slack.print_alert" .}}
  {{ end -}}
  {{ end }}
  {{- end }}
  EOT
}

// OpsGenie contact point
resource "grafana_contact_point" "opsgenie_contact_point" {
  name = "Grafana Alert - Opsgenie"

  opsgenie {
    api_key     = var.opsgenie_api_key
    url         = var.opsgenie_url
    description = "{{ template \"slack.tittle\" . }}" 
    message     = "{{ template \"slack.message\" . }}"
  }
}

// Slack contact point
resource "grafana_contact_point" "slack_contact_point" {
  name = "Grafana Alert - Slack"

  slack {
    recipient = var.slack_recipient
    token     = var.slack_token
    title     = "{{ template \"slack.tittle\" . }}" 
    text      = "{{ template \"slack.message\" . }}"
  }
}

resource "grafana_notification_policy" "notification_policy_1" {
  contact_point = grafana_contact_point.slack_contact_point.name
  group_by      = ["grafana_folder", "alertname"]

  policy {
    contact_point = grafana_contact_point.opsgenie_contact_point.name

    matcher {
      label = "Critical"
      match = "="
      value = "1"
    }
  }
  policy {
    contact_point = grafana_contact_point.slack_contact_point.name

    matcher {
      label = "High"
      match = "="
      value = "1"
    }
    matcher {
      label = "Low"
      match = "="
      value = "1"
    }
  }
}

resource "grafana_rule_group" "rule_group_0000" {
  name             = "Application"
  folder_uid       = grafana_folder.cluster_metrics.uid
  interval_seconds = 60

  rule {
    name      = "ErrImagePullApplication"
    condition = "A"

    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = grafana_data_source.amp.uid
      model          = "{\"editorMode\":\"code\",\"expr\":\"kube_pod_container_status_waiting_reason{reason=\\\"ErrImagePull\\\"} \",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"maxDataPoints\":43200,\"range\":false,\"refId\":\"A\"}"
    }
    data {
      ref_id = "B"

      relative_time_range {
        from = 0
        to   = 0
      }

      datasource_uid = "__expr__"
      model          = "{\"conditions\":[{\"evaluator\":{\"params\":[0,0],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[]},\"reducer\":{\"params\":[],\"type\":\"avg\"},\"type\":\"query\"}],\"datasource\":{\"name\":\"Expression\",\"type\":\"__expr__\",\"uid\":\"__expr__\"},\"expression\":\"A\",\"intervalMs\":1000,\"maxDataPoints\":43200,\"refId\":\"B\",\"type\":\"threshold\"}"
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "5m"
    annotations    = {}
    labels = {
      Critical = "1"
    }
    is_paused = false
  }
  rule {
    name      = "KubeletHealthApplication"
    condition = "A"

    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = grafana_data_source.amp.uid
      model          = "{\"editorMode\":\"code\",\"expr\":\"up{job=\\\"kubelet\\\"} == 0\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"maxDataPoints\":43200,\"range\":false,\"refId\":\"A\"}"
    }
    data {
      ref_id = "B"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"
      model          = "{\"conditions\":[{\"evaluator\":{\"params\":[0,0],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[]},\"reducer\":{\"params\":[],\"type\":\"avg\"},\"type\":\"query\"}],\"datasource\":{\"name\":\"Expression\",\"type\":\"__expr__\",\"uid\":\"__expr__\"},\"expression\":\"A\",\"intervalMs\":1000,\"maxDataPoints\":43200,\"refId\":\"B\",\"type\":\"threshold\"}"
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "5m"
    annotations    = {}
    labels = {
      High = "1"
    }
    is_paused = false
  }
  rule {
    name      = "PodImagePullBackOffApplication"
    condition = "A"

    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = grafana_data_source.amp.uid
      model          = "{\"editorMode\":\"code\",\"expr\":\"kube_pod_container_status_waiting_reason{reason=\\\"ImagePullBackOff\\\"} \",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"maxDataPoints\":43200,\"range\":false,\"refId\":\"A\"}"
    }
    data {
      ref_id = "B"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"
      model          = "{\"conditions\":[{\"evaluator\":{\"params\":[0,0],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[]},\"reducer\":{\"params\":[],\"type\":\"avg\"},\"type\":\"query\"}],\"datasource\":{\"name\":\"Expression\",\"type\":\"__expr__\",\"uid\":\"__expr__\"},\"expression\":\"A\",\"intervalMs\":1000,\"maxDataPoints\":43200,\"refId\":\"B\",\"type\":\"threshold\"}"
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "5m"
    annotations    = {}
    labels = {
      Critical = "1"
    }
    is_paused = false
  }
  rule {
    name      = "PodCrashLoopBackOffApplication"
    condition = "A"

    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = grafana_data_source.amp.uid
      model          = "{\"editorMode\":\"code\",\"expr\":\"kube_pod_container_status_waiting_reason{reason=\\\"CrashLoopBackOff\\\", container!=\\\"iam-accounts-jobs\\\"}\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"maxDataPoints\":43200,\"range\":false,\"refId\":\"A\"}"
    }
    data {
      ref_id = "B"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"
      model          = "{\"conditions\":[{\"evaluator\":{\"params\":[0,0],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[]},\"reducer\":{\"params\":[],\"type\":\"avg\"},\"type\":\"query\"}],\"datasource\":{\"name\":\"Expression\",\"type\":\"__expr__\",\"uid\":\"__expr__\"},\"expression\":\"A\",\"intervalMs\":1000,\"maxDataPoints\":43200,\"refId\":\"B\",\"type\":\"threshold\"}"
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "5m"
    annotations    = {}
    labels = {
      Critical = "1"
    }
    is_paused = false
  }
  rule {
    name      = "NetworkConnectivityApplication"
    condition = "A"

    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = grafana_data_source.amp.uid
      model          = "{\"editorMode\":\"code\",\"expr\":\"sum(rate(node_network_receive_errors_total[5m])) + sum(rate(node_network_transmit_errors_total[5m])) \\u003e 10\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"maxDataPoints\":43200,\"range\":false,\"refId\":\"A\"}"
    }
    data {
      ref_id = "B"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"
      model          = "{\"conditions\":[{\"evaluator\":{\"params\":[0,0],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[]},\"reducer\":{\"params\":[],\"type\":\"avg\"},\"type\":\"query\"}],\"datasource\":{\"name\":\"Expression\",\"type\":\"__expr__\",\"uid\":\"__expr__\"},\"expression\":\"A\",\"intervalMs\":1000,\"maxDataPoints\":43200,\"refId\":\"B\",\"type\":\"threshold\"}"
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "5m"
    labels = {
      High = "1"
    }
    is_paused = false
  }
  rule {
    name      = "HighCpuUsageApplication"
    condition = "A"

    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = grafana_data_source.amp.uid
      model          = "{\"editorMode\":\"code\",\"expr\":\"node_cpu_seconds_total / count(node_cpu_seconds_total) \",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"maxDataPoints\":43200,\"range\":false,\"refId\":\"A\"}"
    }
    data {
      ref_id = "B"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"
      model          = "{\"conditions\":[{\"evaluator\":{\"params\":[0.8,0],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[]},\"reducer\":{\"params\":[],\"type\":\"avg\"},\"type\":\"query\"}],\"datasource\":{\"name\":\"Expression\",\"type\":\"__expr__\",\"uid\":\"__expr__\"},\"expression\":\"A\",\"intervalMs\":1000,\"maxDataPoints\":43200,\"refId\":\"B\",\"type\":\"threshold\"}"
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "5m"
    annotations    = {}
    labels = {
      Critical = "1"
    }
    is_paused = false
  }
  rule {
    name      = "NodeStatusApplication"
    condition = "A"

    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = grafana_data_source.amp.uid
      model          = "{\"editorMode\":\"code\",\"expr\":\"kube_node_status_condition{condition=\\\"Ready\\\", status=\\\"False\\\"}\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"maxDataPoints\":43200,\"range\":false,\"refId\":\"A\"}"
    }
    data {
      ref_id = "B"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"
      model          = "{\"conditions\":[{\"evaluator\":{\"params\":[0,0],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[]},\"reducer\":{\"params\":[],\"type\":\"avg\"},\"type\":\"query\"}],\"datasource\":{\"name\":\"Expression\",\"type\":\"__expr__\",\"uid\":\"__expr__\"},\"expression\":\"A\",\"intervalMs\":1000,\"maxDataPoints\":43200,\"refId\":\"B\",\"type\":\"threshold\"}"
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "5m"
    annotations    = {}
    labels = {
      Critical = "1"
    }
    is_paused = false
  }
  rule {
    name      = "PodOutOfMemoryApplication"
    condition = "A"

    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = grafana_data_source.amp.uid
      model          = "{\"editorMode\":\"code\",\"expr\":\"kube_pod_container_status_waiting_reason{container!=\\\"POD\\\",reason=\\\"OutOfMemory\\\"} \",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"maxDataPoints\":43200,\"range\":false,\"refId\":\"A\"}"
    }
    data {
      ref_id = "B"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"
      model          = "{\"conditions\":[{\"evaluator\":{\"params\":[0,0],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[]},\"reducer\":{\"params\":[],\"type\":\"avg\"},\"type\":\"query\"}],\"datasource\":{\"name\":\"Expression\",\"type\":\"__expr__\",\"uid\":\"__expr__\"},\"expression\":\"A\",\"intervalMs\":1000,\"maxDataPoints\":43200,\"refId\":\"B\",\"type\":\"threshold\"}"
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "5m"
    annotations    = {}
    labels = {
      Critical = "1"
    }
    is_paused = false
  }
  rule {
    name      = " PodPendingForTooLongApplication"
    condition = "A"

    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = grafana_data_source.amp.uid
      model          = "{\"editorMode\":\"code\",\"expr\":\"kube_pod_status_phase{phase=\\\"Pending\\\"} == 1 and time() - kube_pod_metadata_creation_timestamp_seconds{phase=\\\"Pending\\\"}\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"maxDataPoints\":43200,\"range\":false,\"refId\":\"A\"}"
    }
    data {
      ref_id = "B"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"
      model          = "{\"conditions\":[{\"evaluator\":{\"params\":[180,0],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[]},\"reducer\":{\"params\":[],\"type\":\"avg\"},\"type\":\"query\"}],\"datasource\":{\"name\":\"Expression\",\"type\":\"__expr__\",\"uid\":\"__expr__\"},\"expression\":\"A\",\"intervalMs\":1000,\"maxDataPoints\":43200,\"refId\":\"B\",\"type\":\"threshold\"}"
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "5m"
    annotations    = {}
    labels = {
      Critical = "1"
    }
    is_paused = false
  }
}

resource "grafana_rule_group" "rule_group_0001" {
  name             = "Application"
  folder_uid       = grafana_folder.cluster_logs.uid
  interval_seconds = 60

  rule {
    name      = "ApplicationErrorDetectedLow"
    condition = "C"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = grafana_data_source.loki.uid
      model = format(
                "{\"datasource\":{\"type\":\"loki\",\"uid\":\"%s\"},\"editorMode\":\"code\",\"expr\":\"sum by(pod, namespace, env, msg) (count_over_time({job=~\\\".+\\\", namespace!=\\\"loki\\\"} | logfmt |= \\\"level=error\\\" != \\\"there is no access token inside the header\\\" !=\\\"json: cannot unmarshal array into Go struct field JWTAccessClaims.aud of type string\\\" !=\\\"empty status code\\\" | __error__!=\\\"LogfmtParserErr\\\"[5m]))\",\"hide\":false,\"intervalMs\":1000,\"legendFormat\":\"{{pod}}\",\"maxDataPoints\":43200,\"queryType\":\"instant\",\"refId\":\"A\"}",
                grafana_data_source.loki.uid
              )
    }
    data {
      ref_id = "B"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"
      model          = "{\"conditions\":[{\"evaluator\":{\"params\":[],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"B\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"datasource\":{\"type\":\"__expr__\",\"uid\":\"__expr__\"},\"expression\":\"A\",\"intervalMs\":1000,\"maxDataPoints\":43200,\"reducer\":\"sum\",\"refId\":\"B\",\"type\":\"reduce\"}"
    }
    data {
      ref_id = "C"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"
      model          = "{\"conditions\":[{\"evaluator\":{\"params\":[0],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"C\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"datasource\":{\"type\":\"__expr__\",\"uid\":\"__expr__\"},\"expression\":\"B\",\"intervalMs\":1000,\"maxDataPoints\":43200,\"refId\":\"C\",\"type\":\"threshold\"}"
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "5m"
    annotations = {
      __dashboardUid__ = grafana_dashboard.cluster_logs.uid
      __panelId__      = "42"
    }
    labels = {
      Low = "1"
    }
    is_paused = false
  }
  rule {
    name      = "PIIDetectedOrKeywordFoundApplication"
    condition = "C"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = grafana_data_source.loki.uid
      model = format(
                "{\"datasource\":{\"type\":\"loki\",\"uid\":\"%s\"},\"editorMode\":\"code\",\"expr\":\"sum by(pod, namespace, env, msg, args) (count_over_time({namespace=\\\"apps\\\"} | logfmt |~ `(?i)\\\\\\\\b(?:[a-zA-Z0-9._%%+-]+@[a-zA-Z0-9.-]+\\\\\\\\.[a-zA-Z]{2,})\\\\\\\\b|\\\\\\\\b(?:\\\\\\\\d{3}[-.\\\\\\\\s]?\\\\\\\\d{2}[-.\\\\\\\\s]?\\\\\\\\d{4})\\\\\\\\b|\\\\\\\\b(?:\\\\\\\\d{3}[-.\\\\\\\\s]?\\\\\\\\d{3}[-.\\\\\\\\s]?\\\\\\\\d{4})\\\\\\\\b|\\\\\\\\b\\\\\\\\d{10,15}\\\\\\\\b` | __error__!=\\\"LogfmtParserErr\\\" [5m]))\",\"intervalMs\":1000,\"legendFormat\":\"{{pod}}\",\"maxDataPoints\":43200,\"queryType\":\"instant\",\"refId\":\"A\"}",
                grafana_data_source.loki.uid
              )

    }
    data {
      ref_id = "B"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"
      model          = "{\"conditions\":[{\"evaluator\":{\"params\":[],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"B\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"datasource\":{\"type\":\"__expr__\",\"uid\":\"__expr__\"},\"expression\":\"A\",\"intervalMs\":1000,\"maxDataPoints\":43200,\"reducer\":\"sum\",\"refId\":\"B\",\"type\":\"reduce\"}"
    }
    data {
      ref_id = "C"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"
      model          = "{\"conditions\":[{\"evaluator\":{\"params\":[0],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"C\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"datasource\":{\"type\":\"__expr__\",\"uid\":\"__expr__\"},\"expression\":\"B\",\"intervalMs\":1000,\"maxDataPoints\":43200,\"refId\":\"C\",\"type\":\"threshold\"}"
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "5m"
    annotations = {
      __dashboardUid__ = grafana_dashboard.cluster_logs.uid
      __panelId__      = "44"
    }
    labels = {
      High = "1"
    }
    is_paused = false
  }
  rule {
    name      = "SameIPMultipleTimesDetectedApplication"
    condition = "C"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = grafana_data_source.loki.uid
      model = format(
                "{\"datasource\":{\"type\":\"loki\",\"uid\":\"%s\"},\"editorMode\":\"code\",\"expr\":\"sum by(ip_address, uri) (count_over_time({namespace=\\\"ingress-nginx\\\"}| regexp \\\"(?P\\u003cip_address\\u003e\\\\\\\\b(?:[0-9]{1,3}\\\\\\\\.){3}[0-9]{1,3}\\\\\\\\b)\\\" | pattern \\\"\\u003c_\\u003e \\u003c_\\u003e \\u003c_\\u003e \\u003c_\\u003e \\u003c_\\u003e \\u003c_\\u003e \\u003c_\\u003e \\u003c_\\u003e \\u003c_\\u003e \\u003curi\\u003e \\u003c_\\u003e\\\"[5m]))\",\"intervalMs\":1000,\"legendFormat\":\"{{ip_address}}\",\"maxDataPoints\":43200,\"queryType\":\"instant\",\"refId\":\"A\"}",
                grafana_data_source.loki.uid
              )
    }
    data {
      ref_id = "B"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"
      model          = "{\"conditions\":[{\"evaluator\":{\"params\":[],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"B\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"datasource\":{\"type\":\"__expr__\",\"uid\":\"__expr__\"},\"expression\":\"A\",\"intervalMs\":1000,\"maxDataPoints\":43200,\"reducer\":\"sum\",\"refId\":\"B\",\"type\":\"reduce\"}"
    }
    data {
      ref_id = "C"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"
      model          = "{\"conditions\":[{\"evaluator\":{\"params\":[2000],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"C\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"datasource\":{\"type\":\"__expr__\",\"uid\":\"__expr__\"},\"expression\":\"B\",\"intervalMs\":1000,\"maxDataPoints\":43200,\"refId\":\"C\",\"type\":\"threshold\"}"
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "5m"
    annotations = {
      __dashboardUid__ = grafana_dashboard.cluster_logs.uid
      __panelId__      = "46"
    }
    labels = {
      High = "1"
    }
    is_paused = false
  }
  rule {
    name      = "UnauthorizedAccessDetectedApplication"
    condition = "C"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = grafana_data_source.loki.uid
      model = format(
                "{\"datasource\":{\"type\":\"loki\",\"uid\":\"%s\"},\"editorMode\":\"code\",\"expr\":\"sum by(pod, namespace, env)(count_over_time({job=~\\\".+\\\", namespace!=\\\"loki\\\"} | logfmt |= \\\"status=401\\\" | __error__!=\\\"LogfmtParserErr\\\"[5m]))\",\"intervalMs\":1000,\"legendFormat\":\"{{pod}}\",\"maxDataPoints\":43200,\"queryType\":\"instant\",\"refId\":\"A\"}",
                grafana_data_source.loki.uid
              )
    }
    data {
      ref_id = "B"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"
      model          = "{\"conditions\":[{\"evaluator\":{\"params\":[],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"B\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"datasource\":{\"type\":\"__expr__\",\"uid\":\"__expr__\"},\"expression\":\"A\",\"intervalMs\":1000,\"maxDataPoints\":43200,\"reducer\":\"sum\",\"refId\":\"B\",\"type\":\"reduce\"}"
    }
    data {
      ref_id = "C"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"
      model          = "{\"conditions\":[{\"evaluator\":{\"params\":[0],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"C\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"datasource\":{\"type\":\"__expr__\",\"uid\":\"__expr__\"},\"expression\":\"B\",\"intervalMs\":1000,\"maxDataPoints\":43200,\"refId\":\"C\",\"type\":\"threshold\"}"
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "5m"
    annotations = {
      __dashboardUid__ = grafana_dashboard.cluster_logs.uid
      __panelId__      = "48"
    }
    labels = {
      High = "1"
    }
    is_paused = false
  }
  rule {
    name      = "SQLInjectionDetectedApplication"
    condition = "C"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = grafana_data_source.loki.uid
      model = format(
                "{\"datasource\":{\"type\":\"loki\",\"uid\":\"%s\"},\"editorMode\":\"code\",\"expr\":\"sum by(pod, namespace, env, sql)(\\n  count_over_time(\\n    {job=~\\\".+\\\", namespace!=\\\"loki\\\", sql=~\\\"(?i)(OR 1=1|UNION SELECT|--|;--|; DROP|-- DROP|\\\\\\\\bSELECT\\\\\\\\b.*\\\\\\\\bFROM\\\\\\\\b.*--|\\\\\\\\bDELETE\\\\\\\\b.*\\\\\\\\bFROM\\\\\\\\b.*--|\\\\\\\\bINSERT\\\\\\\\b.*\\\\\\\\bINTO\\\\\\\\b.*--|\\\\\\\\bUPDATE\\\\\\\\b.*\\\\\\\\bSET\\\\\\\\b.*--)\\\"} \\n    | logfmt \\n    | __error__!=\\\"LogfmtParserErr\\\"[5m]\\n  )\\n)\",\"intervalMs\":1000,\"legendFormat\":\"{{pod}}\",\"maxDataPoints\":43200,\"queryType\":\"instant\",\"refId\":\"A\"}",
                grafana_data_source.loki.uid
              )

    }
    data {
      ref_id = "B"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"
      model          = "{\"conditions\":[{\"evaluator\":{\"params\":[],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"B\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"datasource\":{\"type\":\"__expr__\",\"uid\":\"__expr__\"},\"expression\":\"A\",\"intervalMs\":1000,\"maxDataPoints\":43200,\"reducer\":\"sum\",\"refId\":\"B\",\"type\":\"reduce\"}"
    }
    data {
      ref_id = "C"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"
      model          = "{\"conditions\":[{\"evaluator\":{\"params\":[0],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"C\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"datasource\":{\"type\":\"__expr__\",\"uid\":\"__expr__\"},\"expression\":\"B\",\"intervalMs\":1000,\"maxDataPoints\":43200,\"refId\":\"C\",\"type\":\"threshold\"}"
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "5m"
    annotations = {
      __dashboardUid__ = grafana_dashboard.cluster_logs.uid
      __panelId__      = "50"
    }
    labels = {
      High = "1"
    }
    is_paused = false
  }
  rule {
    name      = "ApplicationErrorDetected"
    condition = "C"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = grafana_data_source.loki.uid
      model = format(
                "{\"datasource\":{\"type\":\"loki\",\"uid\":\"%s\"},\"editorMode\":\"code\",\"expr\":\"sum by(pod, namespace, env, msg) (count_over_time({job=~\\\".+\\\", namespace!=\\\"loki\\\"} | logfmt |= \\\"level=error\\\" != \\\"there is no access token inside the header\\\" !=\\\"json: cannot unmarshal array into Go struct field JWTAccessClaims.aud of type string\\\" !=\\\"empty status code\\\" !=\\\"error occurred while fetch appointment history\\\" !=\\\"error occurred while fetching policy names by environment id\\\" !=\\\"error occurred while putting record to stream\\\" !=\\\"failed to export save vitals event\\\" !=\\\"failed to find document\\\" !=\\\"failed to get queue url\\\" !=\\\"failed to list policy names by environment ID: rpc error: code = NotFound desc = there are no policies found\\\" !=\\\"no appointments are found\\\" !=\\\"user groups not found for env id\\\" !=\\\"finished call\\\" !=\\\"rolling back transaction because of error during transactions: session not found\\\" !=\\\"session not found\\\" !~\\\"failed to list policy names by tenant group ID and role: rpc error: code = NotFound desc = no policies found for role blueehr and tenant group id\\\" | __error__!=\\\"LogfmtParserErr\\\"[5m]))\",\"intervalMs\":1000,\"legendFormat\":\"{{pod}}\",\"maxDataPoints\":43200,\"queryType\":\"instant\",\"refId\":\"A\"}",
                grafana_data_source.loki.uid
              )
    }
    data {
      ref_id = "B"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "__expr__"
      model          = "{\"conditions\":[{\"evaluator\":{\"params\":[],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"B\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"datasource\":{\"type\":\"__expr__\",\"uid\":\"__expr__\"},\"expression\":\"A\",\"intervalMs\":1000,\"maxDataPoints\":43200,\"reducer\":\"sum\",\"refId\":\"B\",\"type\":\"reduce\"}"
    }
    data {
      ref_id = "C"

      relative_time_range {
        from = 600
        to   = 0
      } 

      datasource_uid = "__expr__"
      model          = "{\"conditions\":[{\"evaluator\":{\"params\":[0],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"C\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"datasource\":{\"type\":\"__expr__\",\"uid\":\"__expr__\"},\"expression\":\"B\",\"intervalMs\":1000,\"maxDataPoints\":43200,\"refId\":\"C\",\"type\":\"threshold\"}"
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "5m"
    annotations = {
      __dashboardUid__ = grafana_dashboard.cluster_logs.uid
      __panelId__      = "42"
    }
    labels = {
      High = "1"
    }
    is_paused = false
  }
}
// Alert ends here...