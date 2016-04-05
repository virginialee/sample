## How to tag

1. Change version in the gemspec file

2. Run `bundle` to update `Gemfile.lock`

3. Update `CHANGE.md`

4. git commit and push

5. `git tag -a {version} -m "{version}"`

6. `git push --follow-tags`
