%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: []
      },
      checks: %{
        enabled: [
          {Control.Checks.EctoKeywordQuery, []},
          {Control.Checks.SingleAssertionPerTest, []},
          {Control.Checks.NoSetupInTest, []}
        ]
      }
    }
  ]
}
