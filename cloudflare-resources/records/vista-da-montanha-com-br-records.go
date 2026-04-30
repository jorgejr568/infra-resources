package records

import (
	"cloudflare-resources/zones"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

var (
	vistaDaMontanhaSubdomains = []string{
		//"@", "www", // root
		"ai",
	}
	vistaDaMontanhaVercelSubdomains = []string{
		"chat",
	}
)

func createVistaDaMontanhaRecords(ctx *pulumi.Context) {
	zs := zones.FromCtx(ctx)
	for _, subdomain := range vistaDaMontanhaSubdomains {
		createAddressRecordsToServer(ctx, createAddressRecordsToServerArgs{
			zoneId:  zs.VistaDaMontanhaZoneId,
			name:    subdomain,
			proxied: true,
		})
	}

	for _, subdomain := range vistaDaMontanhaVercelSubdomains {
		createVercelCname(ctx, createVercelCnameRecordArgs{
			zoneId: zs.VistaDaMontanhaZoneId,
			name:   subdomain,
		})
	}
}
