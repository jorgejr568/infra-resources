package records

import (
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

func CreateRecords(ctx *pulumi.Context) error {
	createEicSeminariosRecords(ctx)
	createJJRRecords(ctx)

	createJorgeJuniorDevRecords(ctx)
	createJorgeJuniorDevMxRecords(ctx)
	createVistaDaMontanhaRecords(ctx)
	createJoyLivingRecords(ctx)
	createRentivoRecords(ctx)
	createHooksFyiRecords(ctx)

	return nil
}
