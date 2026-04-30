package records

import (
	"cloudflare-resources/zones"

	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

var (
	eicSeminariosSubdomains = []string{
		"v2",
	}
)

func createEicSeminariosRecords(ctx *pulumi.Context) {
	zs := zones.FromCtx(ctx)
	for _, subdomain := range eicSeminariosSubdomains {
		createAddressRecordsToServer(ctx, createAddressRecordsToServerArgs{
			zoneId:  zs.EicSeminariosZoneId,
			name:    subdomain,
			proxied: true,
		})
	}
}
