locals {
  python_lambda_function_name             = "lamba_lab_python"
  node_lambda_function_name               = "lambda_lab_node"
  waf_analyzer_lambda                     = "lambda_lab_waf_analyzer"
  waf_threat_correlation_lambda           = "lambda_lab_waf_threat_correlation"
  llm_model_id                            = var.default_bedrock_model_id
  soar_response_agent_function_name       = "lambda_lab_soar_response_agent"
  executive_dashboard_agent_function_name = "lambda_lab_executive_dashboard_agent"
}
