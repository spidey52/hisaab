DELETE FROM "otp_challenges" WHERE "code_hash" IS NULL;--> statement-breakpoint
ALTER TABLE "otp_challenges" ALTER COLUMN "code_hash" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "otp_challenges" DROP COLUMN "provider";--> statement-breakpoint
ALTER TABLE "otp_challenges" DROP COLUMN "provider_reference";
