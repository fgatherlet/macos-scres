#!/usr/bin/env xcrun swift

// Created by John Liu on 2014/10/02.
// Modified by fgatherlet

import Foundation
import ApplicationServices
import CoreVideo

// Swift String is quite powerless at the moment
// http://stackoverflow.com/questions/24044851
// http://openradar.appspot.com/radar?id=6373877630369792
extension String {
    func substringFromLastOcurrenceOf(needle:String) -> String {
        let str = self
        while let range = str.range(of: needle) {
            let index2 = str.index(range.lowerBound, offsetBy:1)
            return String(str[index2 ..< str.endIndex])
        }
        return str
    }

    func toUInt() -> UInt? {
        if let num = Int(self) {
            return UInt(num)
        }
        return nil
    }
}

var display_num_max:UInt32 = 8
var display_num_:UInt32 = 0
var display_ids = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity:Int(display_num_max))

func main () -> Void {
    let error:CGError = CGGetOnlineDisplayList(display_num_max, display_ids, &display_num_)
    if (error != .success) {
        print("ERROR. cannot get online display list.")
        return
    }
    let display_num:Int = Int(display_num_)
    let argc = CommandLine.arguments.count
    let argv = CommandLine.arguments
    if argc <= 1 || argv[1] == "-h" {
        help()
        return
    }
    if argv[1] == "-l" {
        for i in 0 ..< display_num {
            let di = display_info(display_id:display_ids[i], mode:nil)
            print("Display \(i):  \(di.width) * \(di.height) @ \(di.rr)Hz")
        }
        return
    }
    if argv[1] == "-m" && argc == 3 {
        let _di = Int(argv[2])
        if _di == nil || _di! >= display_num {
            help()
            return
        }
        let di = _di!
        let _modes = modes(display_ids[di])
        let display_id = display_ids[di]
        if _modes == nil {
            return
        }
        let modes = _modes!
        print("Supported Modes for Display \(di):")
        let nf = NumberFormatter()
        nf.paddingPosition = NumberFormatter.PadPosition.beforePrefix
        nf.paddingCharacter = " " // XXX: Swift does not support padding yet
        nf.minimumIntegerDigits = 3 // XXX
        for i in 0..<modes.count {
            let di = display_info(display_id:display_id, mode:modes[i])
            print("       \(nf.string(from:NSNumber(value:di.width))!) * \(nf.string(from:NSNumber(value:di.height))!) @ \(di.rr)Hz")
        }
        //}
        return
    }
    if argv[1] == "-s" && argc == 4 {
        let _di = Int(argv[2])
        let _designated_width = argv[3].toUInt()
        if (_di == nil || _designated_width == nil || _di! >= display_num) {
            help()
            return
        }
        let di = _di!
        let designated_width = _designated_width!
        if let modes = modes(display_ids[di]) {
            var mode_index:Int?
            for i in 0..<modes.count {
                let di = display_info(display_id:display_ids[di], mode:modes[i])
                if di.width == designated_width {
                    mode_index = i
                    break
                }
            }
            if mode_index == nil {
                print("this mode is unavailable for current desktop")
                return
            }
            print("setting display mode")
            let display = display_ids[di]
            let mode = modes[mode_index!]

            if !mode.isUsableForDesktopGUI() {
                print("this mode is unavailable for current desktop")
                return
            }

            let config = UnsafeMutablePointer<CGDisplayConfigRef?>.allocate(capacity:1);
            let result = CGBeginDisplayConfiguration(config)
            if result != .success {
                return
            }
            let option:CGConfigureOption = CGConfigureOption(rawValue:2)
            CGConfigureDisplayWithDisplayMode(config.pointee, display, mode, nil)
            let check_result = CGCompleteDisplayConfiguration(config.pointee, option)
            if check_result != .success {
                CGCancelDisplayConfiguration(config.pointee)
            }
        }
        return
    }
    help()
}
func modes(_ display_id:CGDirectDisplayID?) -> [CGDisplayMode]? {
    if display_id == nil {
        return nil
    }
    if let mode_list = CGDisplayCopyAllDisplayModes(display_id!, nil) {
        var mode_array = [CGDisplayMode]()

        let count = CFArrayGetCount(mode_list)
        for i in 0..<count {
            let mode_raw = CFArrayGetValueAtIndex(mode_list, i)
            // https://github.com/FUKUZAWA-Tadashi/FHCCommander
            let mode = unsafeBitCast(mode_raw, to:CGDisplayMode.self)
            mode_array.append(mode)
        }

        return mode_array
    }
    return nil
}
struct DisplayInfo {
    var width:UInt, height:UInt, rr:UInt
}
func display_info(display_id:CGDirectDisplayID, mode:CGDisplayMode?) -> DisplayInfo {
    let mode = (mode == nil) ? CGDisplayCopyDisplayMode(display_id)! : mode!
    let width = UInt(mode.width)
    let height = UInt(mode.height)
    var rr = UInt(mode.refreshRate)

    if rr == 0 {
        var link:CVDisplayLink?
        CVDisplayLinkCreateWithCGDisplay(display_id, &link)
        let time:CVTime = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(link!)
        let time_value = time.timeValue as Int64
        let time_scale = Int64(time.timeScale) + time_value / 2
        rr = UInt( time_scale / time_value )
    }
    return DisplayInfo(width:width, height:height, rr:rr)
}

func help() {
    print("""
            usage:
            command
            [-h]
            [-l]
            [-m display_index]
            [-s display_index width]


            Here are some examples:
            -h          get help
            -l          list displays
            -m 0        list all mode from a certain display
            -s 0 800    set resolution of display 0 to 800*600
            """)
}

// run it
main()
