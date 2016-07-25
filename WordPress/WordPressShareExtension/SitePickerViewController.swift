import Foundation
import UIKit
import WordPressShared
import WordPressComKit


/// This class presents a list of Sites, and allows the user to select one from the list. Works
/// absolutely detached from the Core Data Model, since it was designed for Extension usage.
///
class SitePickerViewController: UITableViewController, UISearchResultsUpdating, UISearchControllerDelegate
{
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupTableView()
        setupNoResultsView()
        setupSearchController()
        setupSearchBar()
        loadSites()
    }


    // MARK: - UITableView Methods
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredSites.count
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return rowHeight
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath: indexPath)
        let site = filteredSites[indexPath.row]

        configureCell(cell, site: site)

        return cell
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let site = filteredSites[indexPath.row]
        onChange?(siteId: site.ID, description: site.name?.characters.count > 0 ? site.name : site.URL.host)
        navigationController?.popViewControllerAnimated(true)
    }


    // MARK: - Setup Helpers
    private func setupView() {
        title = NSLocalizedString("Site Picker", comment: "Title for the Site Picker")
        preferredContentSize = UIScreen.mainScreen().bounds.size
    }

    private func setupTableView() {
        // Blur!
        let blurEffect = UIBlurEffect(style: .Light)
        tableView.backgroundColor = UIColor.clearColor()
        tableView.backgroundView = UIVisualEffectView(effect: blurEffect)
        tableView.separatorEffect = UIVibrancyEffect(forBlurEffect: blurEffect)

        // Fix: Hide the cellSeparators, when the table is empty
        tableView.tableFooterView = UIView()

        // Cells
        tableView.registerClass(WPTableViewCellSubtitle.self, forCellReuseIdentifier: reuseIdentifier)
    }

    private func setupNoResultsView() {
        tableView.addSubview(noResultsView)
    }

    private func setupSearchController() {
        let controller = UISearchController(searchResultsController: nil)
        controller.dimsBackgroundDuringPresentation = false
        controller.hidesNavigationBarDuringPresentation = false
        controller.searchResultsUpdater = self
        controller.delegate = self
        searchController = controller

        // Fix for Invalid Offset Bug
        definesPresentationContext = true
    }

    private func setupSearchBar() {
        precondition(searchController != nil)

        // Setup the SearchBar: Hidden, by default
        let searchBar = searchController.searchBar
        searchBar.searchBarStyle = .Prominent
        searchBar.hidden = true
        tableView.tableHeaderView = searchBar
    }


    // MARK: - Private Helpers
    private func loadSites() {
        guard let oauth2Token = ShareExtensionService.retrieveShareExtensionToken() else {
            showEmptySitesIfNeeded()
            return
        }

        RequestRouter.bearerToken = oauth2Token as String

        let service = SiteService()

        showLoadingView()

        service.fetchSites { [weak self] sites, error in
            dispatch_async(dispatch_get_main_queue()) {
                self?.unfilteredSites = sites ?? [Site]()
                self?.tableView.reloadData()
                self?.showEmptySitesIfNeeded()
                self?.showSearchBarIfNeeded()
            }
        }
    }

    private func configureCell(cell: UITableViewCell, site: Site) {
        // Site's Details
        cell.textLabel?.text = site.name
        cell.detailTextLabel?.text = site.URL.host

        // Site's Blavatar
        cell.imageView?.image = WPStyleGuide.Share.blavatarPlaceholderImage

        if let siteIconPath = site.icon,
            siteIconUrl = NSURL(string: siteIconPath)
        {
            cell.imageView?.downloadBlavatar(siteIconUrl)
        }

        // Style
        WPStyleGuide.Share.configureBlogTableViewCell(cell)
    }


    // MARL: - UISearchControllerDelegate
    func updateSearchResultsForSearchController(searchController: UISearchController) {
        tableView.reloadData()
    }

    func willDismissSearchController(searchController: UISearchController) {
        guard let targetFrame = tableView.tableHeaderView?.frame else {
            return
        }

        tableView.scrollRectToVisible(targetFrame, animated: false)
    }



    // MARK: - No Results Helpers
    private func showLoadingView() {
        noResultsView.titleText = NSLocalizedString("Loading Sites...", comment: "Legend displayed when loading Sites")
        noResultsView.hidden = false
    }

    private func showEmptySitesIfNeeded() {
        let hasSites = (unfilteredSites.isEmpty == false)
        noResultsView.titleText = NSLocalizedString("No Sites", comment: "Legend displayed when the user has no sites")
        noResultsView.hidden = hasSites
    }

    private func showSearchBarIfNeeded() {
        tableView.tableHeaderView?.hidden = unfilteredSites.isEmpty
    }



    // MARK: Typealiases
    typealias PickerHandler = (siteId: Int, description: String?) -> Void

    // MARK: - Public Properties
    var onChange : PickerHandler?

    // MARK: - Private Computed Properties
    private var filteredSites: [Site] {
        guard let keyword = searchController?.searchBar.text?.lowercaseString where keyword.isEmpty == false else {
            return unfilteredSites
        }

        return unfilteredSites.filter { site in
            let matchesName = site.name?.lowercaseString.containsString(keyword) ?? false
            let matchesHost = site.URL?.host?.lowercaseString.containsString(keyword) ?? false
            return matchesName || matchesHost
        }
    }

    // MARK: - Private Properties
    private var unfilteredSites = [Site]()
    private var noResultsView = WPNoResultsView()
    private var searchController: UISearchController!

    // MARK: - Private Constants
    private let rowHeight = CGFloat(74)
    private let reuseIdentifier = "reuseIdentifier"
}
