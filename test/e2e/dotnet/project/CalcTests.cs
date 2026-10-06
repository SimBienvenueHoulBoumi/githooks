using Xunit;

namespace E2e;

public class CalcTests
{
    [Fact]
    public void Add()
    {
        Assert.Equal(3, Calc.Add(1, 2));
    }
}
