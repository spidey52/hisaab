import { z } from "zod";

export const requestOtpSchema = z.object({
  phone: z.string().min(1, "Enter a valid mobile number."),
});

export const verifyOtpSchema = z.object({
  challengeId: z.string().min(1, "Enter the verification code sent to your phone."),
  phone: z.string().min(1, "Enter the verification code sent to your phone."),
  code: z.string().min(1, "Enter the verification code sent to your phone."),
});

export type VerifyOtpBody = z.infer<typeof verifyOtpSchema>;
