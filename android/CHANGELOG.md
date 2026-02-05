### Funcionalidades

- feat(android):  Add migration guide for transitioning from old Android SDK to new SDK (ba49a4f)

### Outros

- Enhance DitoNotificationHandler with error handling for notification processing and device token registration (64ce9f8)
- Update Android SDK publishing configuration to support Maven Central. Change group ID to 'br.com.dito' and adjust build scripts for proper credential handling. Modify publish-all.sh to include error checks for required credentials and streamline the publishing process. Ensure compatibility with both Maven Central and GitHub Packages. (ee72ff0)
- Update Android SDK publishing process to use GitHub Packages instead of Maven Central. Modify README and build configuration to reflect new repository settings and dependency management. Ensure proper credential handling for GitHub authentication in the publish script. (6b7eeb5)
- Refactor DitoCoreDataManager to simplify access to the persistent container by removing the private setter, enhancing code clarity. (3e9a968)
