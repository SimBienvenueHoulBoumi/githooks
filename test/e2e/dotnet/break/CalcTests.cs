using Xunit;

namespace E2e;

public class CalcTests
{
    [Fact]
    public void Add()
    {
        Assert.Equal(4, Calc.Add(1, 2));
    }
}
