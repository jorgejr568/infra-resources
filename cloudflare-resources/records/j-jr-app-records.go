package records

import (
	"cloudflare-resources/zones"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

var (
	jjrSubdomains = []string{
		"@", "www", // root
		"panela-magica-api", "tourquest",
		"wheregoes-api", "wheregoes",
		"yt",
		"flux",
	}
	jjrVerceSubdomains = []string{
		"worktrackr",
		"panela-magica",
	}
)

func createJJRRecords(ctx *pulumi.Context) {
	zs := zones.FromCtx(ctx)
	for _, subdomain := range jjrSubdomains {
		createAddressRecordsToServer(ctx, createAddressRecordsToServerArgs{
			zoneId:  zs.JJRZoneId,
			name:    subdomain,
			proxied: true,
		})
	}

	for _, subdomain := range jjrVerceSubdomains {
		createVercelCname(ctx, createVercelCnameRecordArgs{
			zoneId: zs.JJRZoneId,
			name:   subdomain,
		})
	}
}
