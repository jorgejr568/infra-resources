package records

import (
	"cloudflare-resources/zones"

	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

var (
	rentivoSubdomains = []string{
		"@", "www", // root
	}

	rentivoSesDkimTokens = []string{
		"rcfkehdkxrosoh6amq4gfwernd45mntz",
		"fkb3ccrt3jxioeoty33fahg7fdthbotg",
		"2bh5qi7nuefj7yab2st66flthfdxkwhq",
	}
)

func createRentivoRecords(ctx *pulumi.Context) {
	zs := zones.FromCtx(ctx)
	for _, subdomain := range rentivoSubdomains {
		createAddressRecordsToServer(ctx, createAddressRecordsToServerArgs{
			zoneId:  zs.RentivoZoneId,
			name:    subdomain,
			proxied: true,
		})
	}

	createTxtRecord(ctx, createTxtRecordArgs{
		zoneId:  zs.RentivoZoneId,
		name:    "_dmarc",
		content: "v=DMARC1; p=none;",
	})

	for _, token := range rentivoSesDkimTokens {
		createCnameRecord(ctx, createCnameRecordArgs{
			zoneId:  zs.RentivoZoneId,
			name:    token + "._domainkey",
			content: token + ".dkim.amazonses.com",
			proxied: false,
		})
	}

	createMxRecord(ctx, createMxRecordArgs{
		zoneId:   zs.RentivoZoneId,
		name:     "mail",
		content:  "feedback-smtp.us-east-1.amazonses.com",
		priority: 10,
	})

	createTxtRecord(ctx, createTxtRecordArgs{
		zoneId:  zs.RentivoZoneId,
		name:    "mail",
		content: "v=spf1 include:amazonses.com ~all",
	})
}
