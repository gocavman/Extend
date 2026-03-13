import UIKit

/// Statistics view controller with TableView that slides up from bottom
class StatsViewController: UIViewController {
    var gameState: StickFigureGameState?
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private var stats: [StatSection] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        loadStats()
    }
    
    private func setupUI() {
        // Configure view
        view.backgroundColor = .white
        
        // Configure header
        let header = UIView()
        header.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.98, alpha: 1.0)
        
        let titleLabel = UILabel()
        titleLabel.text = "📊 Statistics"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.textColor = .black
        
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .black
        closeButton.imageView?.contentMode = .scaleAspectFit
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        
        header.addSubview(titleLabel)
        header.addSubview(closeButton)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            
            closeButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),
            
            header.heightAnchor.constraint(equalToConstant: 50)  // Reduced from 60
        ])
        
        // Configure table view
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = .white
        tableView.register(StatTableViewCell.self, forCellReuseIdentifier: "StatCell")
        
        // Reduce section spacing
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0  // Remove extra padding above headers
        }
        
        view.addSubview(header)
        view.addSubview(tableView)
        
        header.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            tableView.topAnchor.constraint(equalTo: header.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadStats() {
        guard let gameState = gameState else { return }
        
        stats = []
        
        // Level & Progress
        var levelSection = StatSection(title: "Level & Progress", rows: [])
        levelSection.rows.append(.stat(label: "Current Level", value: "\(gameState.currentLevel)"))
        levelSection.rows.append(.stat(label: "Current Points", value: "\(gameState.currentPoints)"))
        levelSection.rows.append(.stat(label: "High Score", value: "\(gameState.highScore)"))
        stats.append(levelSection)
        
        // Time
        var timeSection = StatSection(title: "Time", rows: [])
        timeSection.rows.append(.stat(label: "Session Time", value: formatTime(gameState.timeElapsed)))
        timeSection.rows.append(.stat(label: "All Time", value: formatTime(gameState.allTimeElapsed)))
        stats.append(timeSection)
        
        // Performance
        var perfSection = StatSection(title: "Performance", rows: [])
        if !gameState.actionTimes.isEmpty {
            for (action, time) in gameState.actionTimes.sorted(by: { $0.key < $1.key }) {
                perfSection.rows.append(.stat(label: action.capitalized, value: formatTime(time)))
            }
        } else {
            perfSection.rows.append(.stat(label: "No actions performed yet", value: ""))
        }
        stats.append(perfSection)
        
        // Collectibles
        var collectSection = StatSection(title: "Collectibles", rows: [])
        for catchable in CATCHABLE_CONFIGS {
            let count = gameState.catchablesCaught[catchable.id] ?? 0
            let unlocked = gameState.currentLevel >= catchable.unlockLevel
            let value = unlocked ? "\(count) caught" : "Unlocks at Lvl \(catchable.unlockLevel)"
            collectSection.rows.append(.stat(label: catchable.name, value: value))
        }
        stats.append(collectSection)
        
        tableView.reloadData()
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else if minutes > 0 {
            return String(format: "%d:%02d", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension StatsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return stats.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stats[section].rows.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return stats[section].title
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 40  // Reduced from default ~44
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30  // Reduced header height
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 8   // Minimal footer spacing between sections
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StatCell", for: indexPath) as! StatTableViewCell
        let row = stats[indexPath.section].rows[indexPath.row]
        
        if case .stat(let label, let value) = row {
            cell.configure(label: label, value: value)
        }
        
        return cell
    }
}

// MARK: - Data Structures

private struct StatSection {
    let title: String
    var rows: [StatRow]
}

private enum StatRow {
    case stat(label: String, value: String)
}

// MARK: - Custom Table View Cell

class StatTableViewCell: UITableViewCell {
    private let labelView = UILabel()
    private let valueView = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        // Configure label
        labelView.font = UIFont.systemFont(ofSize: 15)
        labelView.textColor = .black
        labelView.numberOfLines = 1
        
        // Configure value
        valueView.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        valueView.textColor = UIColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1.0)
        valueView.numberOfLines = 1
        valueView.textAlignment = .right
        
        // Add to cell
        contentView.addSubview(labelView)
        contentView.addSubview(valueView)
        
        labelView.translatesAutoresizingMaskIntoConstraints = false
        valueView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Label on left
            labelView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            labelView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            labelView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            // Value on right
            valueView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            valueView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            valueView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            // Space between
            labelView.trailingAnchor.constraint(lessThanOrEqualTo: valueView.leadingAnchor, constant: -8)
        ])
    }
    
    func configure(label: String, value: String) {
        labelView.text = label
        valueView.text = value
    }
}
