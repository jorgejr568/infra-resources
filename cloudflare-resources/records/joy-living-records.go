package records

import (
	"cloudflare-resources/zones"

	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

var (
	joyLivingSubdomains = []string{
		"@", "www", // root
		"api",
	}
)

func createJoyLivingRecords(ctx *pulumi.Context) {
	zs := zones.FromCtx(ctx)
	for _, subdomain := range joyLivingSubdomains {
		createAddressRecordsToServer(ctx, createAddressRecordsToServerArgs{
			zoneId:  zs.JoyLivingZoneId,
			name:    subdomain,
			proxied: true,
		})
	}
}
