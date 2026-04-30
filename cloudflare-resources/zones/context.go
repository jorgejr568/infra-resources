package zones

import (
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
	"log"
)

const (
	zonesKey = "zones"
)

func FromCtx(ctx *pulumi.Context) *Zones {
	v, ok := ctx.Value(zonesKey).(*Zones)
	if !ok || v == nil {
		log.Fatalf("zones not found in context")
	}

	return v
}

func ToCtx(ctx *pulumi.Context, v *Zones) *pulumi.Context {
	return ctx.WithValue(zonesKey, v)
}
