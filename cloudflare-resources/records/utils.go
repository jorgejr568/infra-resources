package records

import (
	"cloudflare-resources/constants"
	"fmt"
	"github.com/gosimple/slug"
	"github.com/pulumi/pulumi-cloudflare/sdk/v5/go/cloudflare"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

const (
	vercelCname   = "cname.vercel-dns.com"
	pulumiComment = "Pulumi managed record"
)

type createAddressRecordsToServerArgs struct {
	zoneId  string
	name    string
	proxied bool
}

func createAddressRecordsToServer(ctx *pulumi.Context, args createAddressRecordsToServerArgs) {
	consts := constants.FromCtx(ctx)

	ipv4UrnName := slug.Make(args.name) + "-" + args.zoneId + "-a-record"
	_, err := cloudflare.NewRecord(ctx, ipv4UrnName, &cloudflare.RecordArgs{
		Comment: pulumi.String(pulumiComment),
		Content: pulumi.String(consts.ServerIpv4),
		Name:    pulumi.String(args.name),
		Proxied: pulumi.Bool(args.proxied),
		Type:    pulumi.String("A"),
		ZoneId:  pulumi.String(args.zoneId),
	})
	if err != nil {
		ctx.Log.Error("error creating A record", nil)
	}

	ipv6UrnName := slug.Make(args.name) + "-" + args.zoneId + "-aaaa-record"
	_, err = cloudflare.NewRecord(ctx, ipv6UrnName, &cloudflare.RecordArgs{
		Comment: pulumi.String(pulumiComment),
		Content: pulumi.String(consts.ServerIpv6),
		Name:    pulumi.String(args.name),
		Proxied: pulumi.Bool(args.proxied),
		Type:    pulumi.String("AAAA"),
		ZoneId:  pulumi.String(args.zoneId),
	})

	if err != nil {
		ctx.Log.Error("error creating AAAA record", nil)
	}
}

type createMxRecordArgs struct {
	zoneId   string
	name     string
	content  string
	priority int
}

func createMxRecord(ctx *pulumi.Context, args createMxRecordArgs) {
	_, err := cloudflare.NewRecord(ctx, fmt.Sprintf("%s-%d-%s-mx-record", slug.Make(args.name), args.priority, args.zoneId), &cloudflare.RecordArgs{
		Comment:  pulumi.String(pulumiComment),
		Content:  pulumi.String(args.content),
		Name:     pulumi.String(args.name),
		Priority: pulumi.Int(args.priority),
		Type:     pulumi.String("MX"),
		ZoneId:   pulumi.String(args.zoneId),
	})

	if err != nil {
		ctx.Log.Error("error creating MX record", nil)
	}
}

type createCnameRecordArgs struct {
	zoneId  string
	name    string
	content string
	proxied bool
}

func createCnameRecord(ctx *pulumi.Context, args createCnameRecordArgs) {
	_, err := cloudflare.NewRecord(ctx, fmt.Sprintf("%s-%s-cname-record", slug.Make(args.name), args.zoneId), &cloudflare.RecordArgs{
		Comment: pulumi.String(pulumiComment),
		Content: pulumi.String(args.content),
		Name:    pulumi.String(args.name),
		Type:    pulumi.String("CNAME"),
		ZoneId:  pulumi.String(args.zoneId),
		Proxied: pulumi.Bool(args.proxied),
	})

	if err != nil {
		ctx.Log.Error("error creating CNAME record", nil)
	}
}

type createVercelCnameRecordArgs struct {
	zoneId string
	name   string
}

func createVercelCname(ctx *pulumi.Context, args createVercelCnameRecordArgs) {
	createCnameRecord(ctx, createCnameRecordArgs{
		zoneId:  args.zoneId,
		name:    args.name,
		content: vercelCname,
		proxied: false,
	})
}

type createTxtRecordArgs struct {
	zoneId  string
	name    string
	content string
}

func createTxtRecord(ctx *pulumi.Context, args createTxtRecordArgs) {
	_, err := cloudflare.NewRecord(ctx, fmt.Sprintf("%s-%s-txt-record", slug.Make(args.name), args.zoneId), &cloudflare.RecordArgs{
		Comment: pulumi.String(pulumiComment),
		Content: pulumi.String(args.content),
		Name:    pulumi.String(args.name),
		Type:    pulumi.String("TXT"),
		ZoneId:  pulumi.String(args.zoneId),
	})

	if err != nil {
		ctx.Log.Error("error creating TXT record", nil)
	}
}
