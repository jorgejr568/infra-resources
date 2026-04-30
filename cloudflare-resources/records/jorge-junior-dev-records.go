package records

import (
	"cloudflare-resources/zones"

	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

var (
	jorgeJuniorDevSubdomains = []string{
		"www", "@", // root
		"wheregoes",
		"api",
		"dns",
		"estimates",
		"exchange-register",
		"me",
		"meta",
		"nova",
		"pdf",
		"s3", "s3-manager",
		"flux",
		"vscode",
		"land",
	}
)

func createJorgeJuniorDevRecords(ctx *pulumi.Context) {
	zs := zones.FromCtx(ctx)
	for _, subdomain := range jorgeJuniorDevSubdomains {
		createAddressRecordsToServer(ctx, createAddressRecordsToServerArgs{
			zoneId:  zs.JorgeJuniorDevZoneId,
			name:    subdomain,
			proxied: true,
		})
	}
}

func createJorgeJuniorDevMxRecords(ctx *pulumi.Context) {
	zs := zones.FromCtx(ctx)

	createMxRecord(ctx, createMxRecordArgs{
		zoneId:   zs.JorgeJuniorDevZoneId,
		name:     "bounces",
		content:  "feedback-smtp.sa-east-1.amazonses.com",
		priority: 10,
	})

	createMxRecord(ctx, createMxRecordArgs{
		zoneId:   zs.JorgeJuniorDevZoneId,
		name:     "mg",
		content:  "mxa.mailgun.org",
		priority: 10,
	})

	createMxRecord(ctx, createMxRecordArgs{
		zoneId:   zs.JorgeJuniorDevZoneId,
		name:     "mg",
		content:  "mxb.mailgun.org",
		priority: 20,
	})
}
