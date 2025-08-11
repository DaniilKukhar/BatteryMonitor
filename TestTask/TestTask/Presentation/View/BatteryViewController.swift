import UIKit
import Combine

internal final class BatteryViewController: UIViewController {
    private let viewModel: BatteryViewModel
    private var bag = Set<AnyCancellable>()

    private lazy var percentageLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 48)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "--%"
        return label
    }()

    internal init(viewModel: BatteryViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        title = "Battery Monitor"
    }

    internal required init?(coder: NSCoder) { nil }

    internal override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemYellow

        view.addSubview(percentageLabel)
        NSLayoutConstraint.activate([
            percentageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            percentageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        viewModel.batteryTextPublisher
            .prepend(viewModel.currentBatteryText)
            .receive(on: RunLoop.main)
            .sink { [weak percentageLabel] text in
                percentageLabel?.text = text
            }
            .store(in: &bag)
    }
}
