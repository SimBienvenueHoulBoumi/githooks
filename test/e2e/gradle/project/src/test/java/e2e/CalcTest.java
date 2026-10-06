package e2e;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class CalcTest {
  @Test
  void add() {
    assertEquals(3, Calc.add(1, 2));
  }
}
