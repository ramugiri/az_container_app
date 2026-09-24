# OBS-01/03/04. Replaces the current cluster-wide NFS / Victoria Logs stack.
resource "azurerm_log_analytics_workspace" "mcm" {
  name                = local.names.log_analytics
  location            = azurerm_resource_group.mcm.location
  resource_group_name = azurerm_resource_group.mcm.name
  sku                 = "PerGB2018"
  retention_in_days   = 30 # OBS-03: at least 30 days
  tags                = local.common_tags
}

resource "azurerm_application_insights" "mcm" {
  name                = local.names.app_insights
  location            = azurerm_resource_group.mcm.location
  resource_group_name = azurerm_resource_group.mcm.name
  workspace_id        = azurerm_log_analytics_workspace.mcm.id
  application_type    = "Node.JS"
  tags                = local.common_tags
}

resource "azurerm_monitor_action_group" "as3" {
  name                = local.names.action_group
  resource_group_name = azurerm_resource_group.mcm.name
  short_name          = "mcmas3"
  tags                = local.common_tags

  dynamic "email_receiver" {
    for_each = var.alert_emails
    content {
      name                    = email_receiver.key
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
  # TODO (OBS-04): add the ServiceNow / webhook receiver once AS3 confirms the ITSM integration method.
}

resource "azurerm_monitor_metric_alert" "psql_cpu" {
  name                = "alert-${local.prefix}-psql-cpu"
  resource_group_name = azurerm_resource_group.mcm.name
  scopes              = [azurerm_postgresql_flexible_server.mcm.id]
  description         = "PostgreSQL CPU above 85% for 15 minutes"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = local.common_tags

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "cpu_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = azurerm_monitor_action_group.as3.id
  }
}

resource "azurerm_monitor_metric_alert" "psql_storage" {
  name                = "alert-${local.prefix}-psql-storage"
  resource_group_name = azurerm_resource_group.mcm.name
  scopes              = [azurerm_postgresql_flexible_server.mcm.id]
  description         = "PostgreSQL storage above 85%"
  severity            = 2
  frequency           = "PT15M"
  window_size         = "PT30M"
  tags                = local.common_tags

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "storage_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = azurerm_monitor_action_group.as3.id
  }
}
