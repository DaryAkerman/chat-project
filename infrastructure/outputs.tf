output "public_ip" {
  value = azurerm_public_ip.chat_app_public_ip.ip_address
}

output "port" {
  value = "5000"
}