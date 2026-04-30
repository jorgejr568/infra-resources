package constants

import (
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
	"log"
)

const (
	constantsKey = "constants"
)

func FromCtx(ctx *pulumi.Context) *Constants {
	v, ok := ctx.Value(constantsKey).(*Constants)
	if !ok || v == nil {
		log.Fatalf("constants not found in context")
	}

	return v
}

func ToCtx(ctx *pulumi.Context, v *Constants) *pulumi.Context {
	return ctx.WithValue(constantsKey, v)
}
