<?php

use E2e\Calc;
use PHPUnit\Framework\TestCase;

class CalcTest extends TestCase
{
    public function test_add(): void
    {
        $this->assertSame(4, Calc::add(1, 2));
    }
}
