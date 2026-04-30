package records

import (
	"cloudflare-resources/zones"

	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

var (
	hooksFyiSubdomains = []string{
		"@", "www", // root
	}
)

func createHooksFyiRecords(ctx *pulumi.Context) {
	zs := zones.FromCtx(ctx)
	for _, subdomain := range hooksFyiSubdomains {
		createAddressRecordsToServer(ctx, createAddressRecordsToServerArgs{
			zoneId:  zs.HooksFyiZoneId,
			name:    subdomain,
			proxied: true,
		})
	}
}
