package constants

import (
	"errors"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

const (
	cloudflareAccountIdKey = "cf:accountId"
	serverIpv4Key          = "server:ipv4"
	serverIpv6Key          = "server:ipv6"
)

type Constants struct {
	CloudflareAccountId string
	ServerIpv4          string
	ServerIpv6          string
}

func NewConstants(ctx *pulumi.Context) (*Constants, error) {
	accountId, exists := ctx.GetConfig(cloudflareAccountIdKey)
	if !exists || accountId == "" {
		return nil, errors.New("cloudflare:accountId is required")
	}

	ipv4, exists := ctx.GetConfig(serverIpv4Key)
	if !exists || ipv4 == "" {
		return nil, errors.New("server:ipv4 is required")
	}

	ipv6, exists := ctx.GetConfig(serverIpv6Key)
	if !exists || ipv6 == "" {
		return nil, errors.New("server:ipv6 is required")
	}

	ctx.Export("cloudflare-account-id", pulumi.String(accountId))
	ctx.Export("server-ipv4", pulumi.String(ipv4))
	ctx.Export("server-ipv6", pulumi.String(ipv6))

	return &Constants{
		CloudflareAccountId: accountId,
		ServerIpv4:          ipv4,
		ServerIpv6:          ipv6,
	}, nil
}
