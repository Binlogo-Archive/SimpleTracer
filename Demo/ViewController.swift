//
//  ViewController.swift
//  Demo
//
//  Created by Wang Xingbin on 2018/10/18.
//  Copyright © 2018 Beary Innovative. All rights reserved.
//

import UIKit
import SimpleTracer

class ViewController: UIViewController {
    
    enum TraceTestCase: Int {
        case bearychat
        case github
        case google
        case bing
        case zhihu
        
        var host: String {
            switch self {
            case .bearychat: return "bearychat.com"
            case .github: return "github.com"
            case .google: return "google.com"
            case .bing: return "bing.com"
            case .zhihu: return "zhihu.com"
            }
        }
    }
    
    @IBOutlet weak var hostSegmentedControl: UISegmentedControl!
    @IBOutlet weak var hostLabel: UILabel!
    @IBOutlet weak var resultTextView: UITextView!
    
    private var testCase: TraceTestCase = .bearychat {
        didSet {
            hostLabel.text = testCase.host
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        hostLabel.text = testCase.host
    }
    
    @IBAction func switchHostAction(_ sender: UISegmentedControl) {
        let value = sender.selectedSegmentIndex
        guard let selectedTestCase = TraceTestCase(rawValue: value) else { return }
        testCase = selectedTestCase
    }
    
    @IBAction func startTraceAction(_ sender: Any) {
        resultTextView.text = "Start Trace, good to go."
        SimpleTracer.trace(host: testCase.host, logger: self, maxTraceTTL: 15) { [weak self] (result) in
            self?.resultTextView.text = result
            print(result)
            /**
             Start tracing www.bearychat.com: 54.223.220.218
             #0) 172.25.23.253     5.610 ms    7.405 ms    7.604 ms
             #1) 111.202.166.1     5.999 ms    6.257 ms    6.459 ms
             #2) 202.106.227.105     8.585 ms    8.883 ms    9.079 ms
             #3) 219.232.11.65     6.965 ms  *  *
             #4) 202.96.13.230     12.778 ms    13.112 ms    13.334 ms
             #5) 124.65.226.134     7.564 ms    7.923 ms    8.219 ms
             #6 *  *  *
             #7 *  *  *
             #8) 54.222.25.140     26.394 ms    26.759 ms    26.997 ms
             #9) 54.222.24.176     10.353 ms    10.939 ms    11.384 ms
             #10) 54.222.25.33     8.901 ms    9.516 ms    9.934 ms
             #11 *  *  *
             #12 *  *  *
             #13 *  *  *
             ### Host responsed, latency (ms): 7.927060127258301 ms
             #14 Data received, size=64
             #14 reach the destination 54.223.220.218, trace completed. It's simple! Right?
             ***/
        }
    }
    
}

extension ViewController: SimpleTracerLogger {
    func logTrace(_ trace: String) {
        DispatchQueue.main.async {
            self.resultTextView.text += trace
        }
    }
}
