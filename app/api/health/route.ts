import { connection } from "next/server";
import { NextResponse } from "next/server";

export async function GET() {
  // Opts this route out of prerendering, so APP_VERSION is read at request time.
  await connection();

  return NextResponse.json({
    status: "ok",
    version: process.env.APP_VERSION ?? "unknown",
  });
}
