locals {
  infra_mode_normalized = lower(var.infra_mode)
  infra_active          = var.manage_hybrid_infra && local.infra_mode_normalized == "active"
  infra_hibernated      = var.manage_hybrid_infra && local.infra_mode_normalized == "hibernated"

  nat_requires_eip = local.infra_active && var.nat != null && try(var.nat.allocation_id, null) == null && try(var.nat.create_eip, true)
}

check "confirm_hibernation_destroy" {
  assert        = !local.infra_hibernated || var.allow_destroy
  error_message = "infra_mode=hibernated is destructive. Set allow_destroy=true to proceed."
}

check "rds_final_snapshot_required" {
  assert = !local.infra_hibernated || var.rds == null || try(var.rds.final_snapshot_identifier, null) != null
  error_message = "When hibernating RDS, set rds.final_snapshot_identifier to avoid accidental snapshot naming conflicts."
}

resource "aws_lb_target_group" "alb" {
  count       = local.infra_active && var.alb != null ? 1 : 0
  name        = var.alb.target_group.name
  port        = var.alb.target_group.port
  protocol    = var.alb.target_group.protocol
  target_type = try(var.alb.target_group.target_type, "ip")
  vpc_id      = var.vpc_id

  health_check {
    enabled = true
    path    = try(var.alb.target_group.health_check_path, "/")
  }
}

resource "aws_lb" "alb" {
  count                      = local.infra_active && var.alb != null ? 1 : 0
  name                       = var.alb.name
  internal                   = var.alb.internal
  load_balancer_type         = "application"
  security_groups            = var.alb.security_group_ids
  subnets                    = var.alb.subnet_ids
  idle_timeout               = try(var.alb.idle_timeout, 60)
  enable_deletion_protection = try(var.alb.enable_deletion_protection, false)
  tags                       = try(var.alb.tags, {})
}

resource "aws_lb_listener" "alb" {
  count             = local.infra_active && var.alb != null ? 1 : 0
  load_balancer_arn = aws_lb.alb[0].arn
  port              = try(var.alb.listener_port, 443)
  protocol          = try(var.alb.listener_protocol, "HTTPS")
  certificate_arn   = try(var.alb.certificate_arn, null)

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb[0].arn
  }
}

resource "aws_route53_record" "alb_alias" {
  count   = local.infra_active && var.alb != null && try(var.alb.route53_record_name, null) != null && try(var.alb.route53_zone_id, null) != null ? 1 : 0
  zone_id = var.alb.route53_zone_id
  name    = var.alb.route53_record_name
  type    = "A"

  alias {
    name                   = aws_lb.alb[0].dns_name
    zone_id                = aws_lb.alb[0].zone_id
    evaluate_target_health = true
  }
}

resource "aws_lb_target_group" "nlb" {
  count       = local.infra_active && var.nlb != null ? 1 : 0
  name        = var.nlb.target_group.name
  port        = var.nlb.target_group.port
  protocol    = var.nlb.target_group.protocol
  target_type = try(var.nlb.target_group.target_type, "ip")
  vpc_id      = var.vpc_id
}

resource "aws_lb" "nlb" {
  count              = local.infra_active && var.nlb != null ? 1 : 0
  name               = var.nlb.name
  internal           = var.nlb.internal
  load_balancer_type = "network"
  subnets            = var.nlb.subnet_ids
  tags               = try(var.nlb.tags, {})
}

resource "aws_lb_listener" "nlb" {
  count             = local.infra_active && var.nlb != null ? 1 : 0
  load_balancer_arn = aws_lb.nlb[0].arn
  port              = try(var.nlb.listener_port, 5672)
  protocol          = try(var.nlb.listener_protocol, "TCP")

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb[0].arn
  }
}

resource "aws_route53_record" "nlb_alias" {
  count   = local.infra_active && var.nlb != null && try(var.nlb.route53_record_name, null) != null && try(var.nlb.route53_zone_id, null) != null ? 1 : 0
  zone_id = var.nlb.route53_zone_id
  name    = var.nlb.route53_record_name
  type    = "A"

  alias {
    name                   = aws_lb.nlb[0].dns_name
    zone_id                = aws_lb.nlb[0].zone_id
    evaluate_target_health = true
  }
}

resource "aws_eip" "nat" {
  count = local.nat_requires_eip ? 1 : 0
  tags  = try(var.nat.eip_tags, {})
}

resource "aws_nat_gateway" "this" {
  count         = local.infra_active && var.nat != null ? 1 : 0
  subnet_id     = var.nat.subnet_id
  allocation_id = try(var.nat.allocation_id, null) != null ? var.nat.allocation_id : aws_eip.nat[0].id
  tags          = try(var.nat.nat_tags, {})
}

resource "aws_route" "private_default_ipv4" {
  for_each = local.infra_active && var.nat != null ? toset(var.nat.private_route_table_ids) : toset([])

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

resource "aws_db_subnet_group" "this" {
  count      = local.infra_active && var.rds != null && try(var.rds.db_subnet_group_name, null) == null ? 1 : 0
  name       = "${var.rds.identifier}-subnet-group"
  subnet_ids = var.rds.db_subnet_ids
}

data "aws_db_snapshot" "latest" {
  count                  = local.infra_active && var.rds != null && try(var.rds.restore_snapshot_identifier, null) == null && try(var.rds.restore_from_latest_snapshot, true) ? 1 : 0
  db_instance_identifier = try(var.rds.source_instance_identifier, var.rds.identifier)
  most_recent            = true
  include_public         = false
  include_shared         = false
}

locals {
  rds_snapshot_identifier = local.infra_active && var.rds != null ? coalesce(
    try(var.rds.restore_snapshot_identifier, null),
    try(data.aws_db_snapshot.latest[0].id, null)
  ) : null
}

resource "aws_db_instance" "this" {
  count = local.infra_active && var.rds != null ? 1 : 0

  identifier             = var.rds.identifier
  instance_class         = var.rds.instance_class
  snapshot_identifier    = local.rds_snapshot_identifier
  db_subnet_group_name   = try(var.rds.db_subnet_group_name, null) != null ? var.rds.db_subnet_group_name : aws_db_subnet_group.this[0].name
  vpc_security_group_ids = var.rds.vpc_security_group_ids
  publicly_accessible    = try(var.rds.publicly_accessible, false)
  multi_az               = try(var.rds.multi_az, false)
  deletion_protection    = try(var.rds.deletion_protection, false)
  apply_immediately      = try(var.rds.apply_immediately, true)
  skip_final_snapshot    = false
  final_snapshot_identifier = coalesce(
    try(var.rds.final_snapshot_identifier, null),
    "${var.rds.identifier}-final-snapshot"
  )
  tags = try(var.rds.tags, {})
}
