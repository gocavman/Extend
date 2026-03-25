import UIKit

/// View controller for action selection with slide-up animation
class ActionSelectionViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var actions: [ActionConfig] = []
    var onActionSelected: ((ActionConfig) -> Void)?
    var onDismiss: (() -> Void)?
    
    private let tableView = UITableView()
    private let dismissArea = UIView()
    private let transitionController = ActionSelectionTransitionController()
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setupPresentationStyle()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPresentationStyle()
    }
    
    private func setupPresentationStyle() {
        self.modalPresentationStyle = .overFullScreen
        self.transitioningDelegate = transitionController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("🎮 ActionSelectionViewController viewDidLoad")
        print("🎮 Actions available: \(actions.count)")
        
        // Make absolutely sure the view is transparent
        self.view.backgroundColor = .clear
        self.view.isOpaque = false
        self.view.layer.backgroundColor = UIColor.clear.cgColor
        self.view.layer.isOpaque = false
        
        setupUI()
        animateSlideUp()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Ensure transparency at presentation time
        view.backgroundColor = .clear
        view.isOpaque = false
    }
    
    private func setupUI() {
        print("🎮 ActionSelectionViewController setupUI - view bounds: \(view.bounds)")
        
        // Make the main view completely transparent and non-interactive except for our components
        view.backgroundColor = .clear
        view.isOpaque = false
        view.layer.backgroundColor = UIColor.clear.cgColor
        
        // Hide the main view itself to prevent any background rendering
        for subview in view.subviews {
            if subview != tableView && subview != dismissArea {
                subview.isHidden = true
            }
        }
        
        // Dismiss area (tap outside to close) - completely transparent, doesn't intercept touches above table
        dismissArea.backgroundColor = .clear
        dismissArea.isOpaque = false
        dismissArea.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - CGFloat(actions.count * 60 + 30))
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissViewController))
        dismissArea.addGestureRecognizer(tapGesture)
        view.addSubview(dismissArea)
        print("🎮 Dismiss area added - frame: \(dismissArea.frame)")
        
        // Table view setup
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ActionTableViewCell.self, forCellReuseIdentifier: "ActionCell")
        tableView.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 0.95)
        tableView.separatorColor = UIColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 0.5)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.rowHeight = 60
        tableView.layer.cornerRadius = 12
        tableView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        tableView.clipsToBounds = true
        
        view.addSubview(tableView)
        
        // Layout table view to slide up from bottom
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.heightAnchor.constraint(equalToConstant: CGFloat(actions.count * 60 + 30))
        ])
    }
    
    private func animateSlideUp() {
        tableView.transform = CGAffineTransform(translationX: 0, y: tableView.frame.height)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            self.tableView.transform = .identity
        })
    }
    
    @objc private func dismissViewController() {
        animateDismiss()
    }
    
    private func animateDismiss() {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn, animations: {
            self.tableView.transform = CGAffineTransform(translationX: 0, y: self.tableView.frame.height)
        }, completion: { _ in
            self.dismiss(animated: false)
            self.onDismiss?()
        })
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return actions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath) as! ActionTableViewCell
        let action = actions[indexPath.row]
        cell.configure(with: action)
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedAction = actions[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Animate dismiss
        animateDismiss()
        
        // Call the selection callback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.onActionSelected?(selectedAction)
        }
    }
}

// MARK: - Action Table View Cell

class ActionTableViewCell: UITableViewCell {
    private let iconLabel = UILabel()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let chevronLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        let selectedBackground = UIView()
        selectedBackground.backgroundColor = UIColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 0.5)
        selectedBackgroundView = selectedBackground
        
        // Icon
        iconLabel.font = UIFont.systemFont(ofSize: 24)
        iconLabel.textAlignment = .center
        contentView.addSubview(iconLabel)
        
        // Title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = .white
        contentView.addSubview(titleLabel)
        
        // Points
        descriptionLabel.font = UIFont.systemFont(ofSize: 12)
        descriptionLabel.textColor = UIColor(red: 0.7, green: 0.7, blue: 0.75, alpha: 1.0)
        contentView.addSubview(descriptionLabel)
        
        // Chevron
        chevronLabel.text = "›"
        chevronLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        chevronLabel.textColor = UIColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1.0)
        contentView.addSubview(chevronLabel)
        
        // Layout
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        chevronLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Icon
            iconLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 40),
            
            // Title
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: chevronLabel.leadingAnchor, constant: -8),
            
            // Description
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            descriptionLabel.trailingAnchor.constraint(equalTo: chevronLabel.leadingAnchor, constant: -8),
            
            // Chevron
            chevronLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            chevronLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    func configure(with action: ActionConfig) {
        // Emoji for action
        let icons: [String: String] = [
            "rest": "😴",
            "run": "🏃",
            "jump": "🦘",
            "jumpingjack": "🤸",
            "yoga": "🧘",
            "curls": "💪",
            "kettlebell": "🪜",
            "pushup": "🤲",
            "pullup": "📍",
            "meditation": "🧠"
        ]
        
        iconLabel.text = icons[action.id] ?? "🎯"
        titleLabel.text = action.displayName
        descriptionLabel.text = "\(action.pointsPerCompletion) pts per completion"
    }
}

// MARK: - Transitioning Controller

class ActionSelectionTransitionController: NSObject, UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return ClearBackgroundPresentationController(presentedViewController: presented, presenting: presenting)
    }
}

// MARK: - Clear Background Presentation Controller

class ClearBackgroundPresentationController: UIPresentationController {
    override var shouldPresentInFullscreen: Bool {
        return true
    }
    
    override func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()
        setupTransparentBackground()
    }
    
    override var frameOfPresentedViewInContainerView: CGRect {
        return containerView?.bounds ?? .zero
    }
    
    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        setupTransparentBackground()
    }
    
    private func setupTransparentBackground() {
        // Set container to transparent
        containerView?.backgroundColor = .clear
        
        // Remove any dimming views that might have been added
        if let containerView = containerView {
            for subview in containerView.subviews {
                if subview != presentedView && subview.backgroundColor != .clear {
                    subview.backgroundColor = .clear
                    subview.alpha = 0
                }
            }
        }
        
        presentedViewController.view.backgroundColor = .clear
    }
}
