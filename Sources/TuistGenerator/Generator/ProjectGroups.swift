import Foundation
import TSCBasic
import TuistCore
import TuistGraph
import TuistSupport
import XcodeProj

enum ProjectGroupsError: FatalError, Equatable {
    case missingGroup(String)

    var description: String {
        switch self {
        case let .missingGroup(group):
            return "Couldn't find group: \(group)"
        }
    }

    var type: ErrorType {
        switch self {
        case .missingGroup:
            return .bug
        }
    }
}

class ProjectGroups {
    // MARK: - Attributes

    @SortedPBXGroup var sortedMain: PBXGroup
    let products: PBXGroup
    let frameworks: PBXGroup
    let cachedFrameworks: PBXGroup

    private let pbxproj: PBXProj
    private let projectGroups: [String: PBXGroup]

    // MARK: - Init

    private init(
        main: PBXGroup,
        projectGroups: [(name: String, group: PBXGroup)],
        products: PBXGroup,
        frameworks: PBXGroup,
        cachedFrameworks: PBXGroup,
        pbxproj: PBXProj
    ) {
        sortedMain = main
        self.projectGroups = Dictionary(uniqueKeysWithValues: projectGroups)
        self.products = products
        self.frameworks = frameworks
        self.cachedFrameworks = cachedFrameworks
        self.pbxproj = pbxproj
    }

    func targetFrameworks(target: String) throws -> PBXGroup {
        if let group = frameworks.group(named: target) {
            return group
        } else {
            return try frameworks.addGroup(named: target, options: .withoutFolder).last!
        }
    }

    func projectGroup(named name: String) throws -> PBXGroup {
        guard let group = projectGroups[name] else {
            throw ProjectGroupsError.missingGroup(name)
        }
        return group
    }

    static func generate(
        project: Project,
        pbxproj: PBXProj
    ) -> ProjectGroups {
        /// Main
        let projectRelativePath = project.sourceRootPath.relative(to: project.xcodeProjPath.parentDirectory).pathString
        let textSettings = project.options.textSettings
        let mainGroup = PBXGroup(
            children: [],
            sourceTree: .group,
            path: (projectRelativePath != ".") ? projectRelativePath : nil,
            wrapsLines: textSettings.wrapsLines,
            usesTabs: textSettings.usesTabs,
            indentWidth: textSettings.indentWidth,
            tabWidth: textSettings.tabWidth
        )
        pbxproj.add(object: mainGroup)

        /// Project & Target Groups
        let projectGroupNames = extractProjectGroupNames(from: project)
        let groupsToCreate = OrderedSet(projectGroupNames)
        var projectGroups = [(name: String, group: PBXGroup)]()
        for item in groupsToCreate {
            let projectGroup = PBXGroup(children: [], sourceTree: .group, name: item)
            pbxproj.add(object: projectGroup)
            mainGroup.children.append(projectGroup)
            projectGroups.append((item, projectGroup))
        }

        /// SDSKs & Pre-compiled frameworks
        let frameworksGroup = PBXGroup(children: [], sourceTree: .group, name: "Frameworks")
        pbxproj.add(object: frameworksGroup)
        mainGroup.children.append(frameworksGroup)

        /// Cached frameworks
        let cacheGroup = PBXGroup(children: [], sourceTree: .group, name: "Cache")
        pbxproj.add(object: cacheGroup)
        mainGroup.children.append(cacheGroup)

        /// Products
        let productsGroup = PBXGroup(children: [], sourceTree: .group, name: "Products")
        pbxproj.add(object: productsGroup)
        mainGroup.children.append(productsGroup)

        return ProjectGroups(
            main: mainGroup,
            projectGroups: projectGroups,
            products: productsGroup,
            frameworks: frameworksGroup,
            cachedFrameworks: cacheGroup,
            pbxproj: pbxproj
        )
    }

    private static func extractProjectGroupNames(from project: Project) -> [String] {
        let groups = [project.filesGroup] + project.targets.map(\.filesGroup)
        let groupNames: [String] = groups.compactMap {
            switch $0 {
            case let .group(name: groupName):
                return groupName
            }
        }
        return groupNames
    }
}
