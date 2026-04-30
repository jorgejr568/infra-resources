package zones

import (
	"fmt"

	"github.com/pulumi/pulumi-cloudflare/sdk/v5/go/cloudflare"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

type Zones struct {
	EicSeminariosZoneId   string
	JJRZoneId             string
	JorgeJuniorDevZoneId  string
	VistaDaMontanhaZoneId string
	JoyLivingZoneId       string
	RentivoZoneId         string
	HooksFyiZoneId        string
}

func NewZones(ctx *pulumi.Context) (*Zones, error) {
	eicSeminarios, err := lookupZone(ctx, "eic-seminarios.com")
	if err != nil {
		return nil, err
	}
	jjr, err := lookupZone(ctx, "j-jr.app")
	if err != nil {
		return nil, err
	}
	jorgeJunior, err := lookupZone(ctx, "jorgejunior.dev")
	if err != nil {
		return nil, err
	}
	vistaDaMontanha, err := lookupZone(ctx, "vistadamontanha.com.br")
	if err != nil {
		return nil, err
	}
	joyLiving, err := lookupZone(ctx, "joyliving.com.br")
	if err != nil {
		return nil, err
	}
	rentivo, err := lookupZone(ctx, "rentivo.com.br")
	if err != nil {
		return nil, err
	}
	hooksFyi, err := lookupZone(ctx, "hooks.fyi")
	if err != nil {
		return nil, err
	}

	ctx.Export("eic-seminarios-zone-id", pulumi.String(eicSeminarios.ZoneId))
	ctx.Export("j-jr-zone-id", pulumi.String(jjr.ZoneId))
	ctx.Export("jorgejunior.dev-zone-id", pulumi.String(jorgeJunior.ZoneId))
	ctx.Export("vista-da-montanha-zone-id", pulumi.String(vistaDaMontanha.ZoneId))
	ctx.Export("joyliving-zone-id", pulumi.String(joyLiving.ZoneId))
	ctx.Export("rentivo-zone-id", pulumi.String(rentivo.ZoneId))
	ctx.Export("hooks-fyi-zone-id", pulumi.String(hooksFyi.ZoneId))

	return &Zones{
		EicSeminariosZoneId:   eicSeminarios.ZoneId,
		JJRZoneId:             jjr.ZoneId,
		JorgeJuniorDevZoneId:  jorgeJunior.ZoneId,
		VistaDaMontanhaZoneId: vistaDaMontanha.ZoneId,
		JoyLivingZoneId:       joyLiving.ZoneId,
		RentivoZoneId:         rentivo.ZoneId,
		HooksFyiZoneId:        hooksFyi.ZoneId,
	}, nil
}

func lookupZone(ctx *pulumi.Context, name string) (*cloudflare.LookupZoneResult, error) {
	result, err := cloudflare.LookupZone(ctx, &cloudflare.LookupZoneArgs{
		Name: pulumi.StringRef(name),
	})
	if err != nil {
		ctx.Log.Error(fmt.Sprintf("error on zone lookup for: %s", name), nil)
		return nil, err
	}

	return result, nil
}
