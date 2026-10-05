#!/usr/bin/env bash
# .NET (ASP.NET, C#, F#) : dotnet format, dotnet test
register dotnet "*.sln *.slnx *.csproj *.fsproj *.vbproj" '\.(cs|fs|vb)$' outermost

dotnet_format() {
    has dotnet || { tool_missing ".NET : dotnet absent, formatage ignoré."; return 0; }
    step ".NET : dotnet format"
    dotnet format --include "$@"
}

dotnet_test() {
    has dotnet || { warn ".NET : dotnet absent, tests ignorés."; return 0; }
    step ".NET : dotnet test"
    dotnet test --nologo -v q
}
