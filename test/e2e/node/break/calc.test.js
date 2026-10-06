import { test } from "node:test";
import assert from "node:assert";
import { add } from "./calc.js";

test("add", () => assert.equal(add(1, 2), 4));
