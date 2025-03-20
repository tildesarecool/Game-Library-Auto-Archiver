Describe "GameLibAutoArchiver Module" {
    It "Module should exist" {
        Test-Path "$PSScriptRoot\..\GameLibAutoArchiver.psm1" | Should -Be $true
    }
}
