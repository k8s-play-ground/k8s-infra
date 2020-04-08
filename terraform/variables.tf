variable "node_count" {
  default = "3"
 }
variable "master_count" {
  default = "3"
 }
variable "lb_ports" {
  type        = map(string)
  default = { 
      "8080" = "10254"
      "6443" = "6443"
    }
 }
variable "lb_healthcheck_ports" {
  default = { 
      "8080" = 1
      "10254" = 2
    }
 }
variable "ingress_port" {
  default = "8080"
 }
variable "ingress_health_port" {
  default = "10254"
 }
variable "ingress_endpoint_host" {
  type    = string
  default = "pdas-sbx-ingress.default.svc.cluster.locald"
 }
variable "ingress_lb_name" {
  type    = string
  default = "paas-sbx-ingress"
 }
variable "ingress_node_list"{
  type    = list
  default = [
    		"asia-south1-a/paas-sbx-worker-0",
    		"asia-south1-a/paas-sbx-worker-1",
    		"asia-south1-a/paas-sbx-worker-2",
  ]
 }   
