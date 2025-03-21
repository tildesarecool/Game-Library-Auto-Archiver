# Tests/gamelibautoarchiver.Tests.ps1
Describe "GameLibAutoArchiver Module" {
    It "Module should exist" {
        Test-Path "$PSScriptRoot\..\GameLibAutoArchiver\gamelibautoarchiver.psm1" | Should -Be $true
    }
}