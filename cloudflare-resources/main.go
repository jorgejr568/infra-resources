package main

import (
	"cloudflare-resources/constants"
	"cloudflare-resources/records"
	"cloudflare-resources/zones"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

func main() {
	pulumi.Run(func(ctx *pulumi.Context) error {
		ctx, err := setupCtx(ctx)
		if err != nil {
			return err
		}

		if err := records.CreateRecords(ctx); err != nil {
			return err
		}

		return nil
	})
}

func setupCtx(ctx *pulumi.Context) (*pulumi.Context, error) {
	consts, err := constants.NewConstants(ctx)
	if err != nil {
		return nil, err
	}
	// Write the constants to the context
	ctx = constants.ToCtx(ctx, consts)

	zs, err := zones.NewZones(ctx)
	if err != nil {
		return nil, err
	}
	// Write the zones to the context
	ctx = zones.ToCtx(ctx, zs)

	return ctx, nil
}
