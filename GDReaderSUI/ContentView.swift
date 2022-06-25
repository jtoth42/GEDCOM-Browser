//
//  ContentView.swift
//  GDReaderSUI
//
//  Created by Jim on 5/25/22.
//

import SwiftUI

struct ContentView: View {

  @State private var text: String = """
  0 HEAD
  1 GEDC
  2 VERS 7.0
  0 @I1@ INDI
  1 NAME John /Smith/
  1 FAMS @F1@
  0 @I2@ INDI
  1 NAME Jane /Doe/
  1 FAMS @F1@
  0 @F1@ FAM
  1 HUSB @I1@
  1 WIFE @I2@
  0 @S1@ SOUR
  1 TITL Source One
  0 @N1@ SNOTE Shared note 1
  0 TRLR
  """
  
  struct Family: Identifiable, Comparable {
    let id: String
    let husb: String
    let wife: String
    let textContent: String
    static func < (lhs: Family, rhs: Family) -> Bool { lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending }
  }
  @State private var families = [
    Family(id: "F1", husb: "Smith", wife: "Doe", textContent: "FAM\n1 HUSB @I1@\n1 WIFE @I2@")
  ]
  
  struct Individual: Identifiable, Comparable {
    let id: String
    let name: String
    let textContent: String
    static func < (lhs: Individual, rhs: Individual) -> Bool { lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending }
  }
  @State private var individuals = [
    Individual(id: "I1", name: "Smith John", textContent:"INDI\n1 NAME John /Smith/\n1 FAMS @F1@"), Individual(id: "I2", name: "Doe Jane", textContent:"INDI\n1 NAME Jane /Doe/\n1 FAMS @F1@")
  ]
  
  @State private var sources = ["S1": "SOUR\n1 TITL Source One"]
  @State private var others = ["HEAD": "1 GEDC\n2 VERS 7.0", "N1": "SNOTE Shared note 1\n0 TRLR"]
  @State private var currentFileName: String = "click Open New"
  
  var body: some View {
    HStack {
      VStack (alignment: .leading) {
        Text(currentFileName)
        TextEditor(text: $text)
          .font(.body)
        HStack() {
          Button(action: {
            let openURL = showOpenPanel()
            readText(from: openURL)
            }, label: {
              HStack {
                Image(systemName: "square.and.arrow.up")
                        Text("Open New")
              }
              .frame(width: 120)
            })
          Button(action: {
              processText()
            }, label: {
              Text("Process")
              .frame(width: 80)
            })
          Spacer()
          }
          .padding(20)
      } // end of VStack One Closure
      .frame(width: 300.0)
      VStack (alignment: .leading) {
        HStack(){
          Text(" FAM")
            .frame(minWidth: 50.0)
          Text("HUSB/WIFE")
        }
        NavigationView {
          List() {
             ForEach(families.sorted()) { Family in
                NavigationLink( destination: RecordDetail(recordText: Family.textContent)) {
                  Text(Family.id)
                  Text(Family.husb)
                  Text(Family.wife)
                }
             }
          }
          Text("No selection")
        }
        HStack() {
          Text("  INDI")
            .frame(width: 50.0)
          Text("Name")
        }
        NavigationView {
          List() {
            ForEach(individuals.sorted()) { Individual in
              NavigationLink( destination: RecordDetail(recordText: Individual.textContent)) {
                Text(Individual.id)
                Text(Individual.name)
              }
            }
          }
          Text("No selection")
       }
      } // end of VStack Two Closure
      VStack(alignment: .leading) {
        Text("SOUR")
        NavigationView {
          List {
            ForEach(sources.sorted(by: {$0.key.localizedStandardCompare($1.key) == .orderedAscending}), id: \.key) { key, value in
                NavigationLink(key, destination: RecordDetail(recordText: value))
            }
           }
          Text("No selection")
        }
        Text("Other")
        NavigationView {
          List {
            ForEach(others.sorted(by: {$0.key.localizedStandardCompare($1.key) == .orderedAscending}), id: \.key) { key, value in
                NavigationLink(key, destination: RecordDetail(recordText: value))
            }
          }
          Text("No selection")
        }
      } // end of VStack Three Closure
    } // end of HStack
  } // end of body/view
  
  func showOpenPanel() -> URL? {
      let openPanel = NSOpenPanel()
      openPanel.allowedContentTypes = []
      openPanel.allowsMultipleSelection = false
      openPanel.canChooseDirectories = false
      openPanel.canChooseFiles = true
      let response = openPanel.runModal()
      return response == .OK ? openPanel.url : nil
  }
  
  func readText(from url: URL?) {
    guard let url = url else { return }
    do {
      let loadedText = try String(contentsOf: url)
      text = loadedText
      currentFileName = url.lastPathComponent
    }
    catch {
      guard let loadedText = try? String(contentsOf: url, encoding: String.Encoding.macOSRoman) else { return }
      text = loadedText
    }
  }
  
  func processText() {
// Splits "text" into GEDCOM records,
// and then does additional processing
// of the family and individual records.
// The while loop at its beginning
// reads the full content of the current
// record and then at the end of the loop
// reads the xRef for the next record.
// The TRLR "pseudo-record" gets read into
// the textContent for the last data record.
    var famDict: [String: String] = [:]
    var indivDict: [String: String] = [:]
    var sourceDict: [String: String] = [:]
    var otherDict: [String: String] = [:]
    let mysca = Scanner(string: text)
    guard let _ = mysca.scanString("0 "),
          let _ = mysca.scanString("HEAD")
    else {
      print("failed on header record")
      return
    }
    var xRef = "HEAD"  // Not an xRef.
    while !mysca.isAtEnd {
      guard let textContent = mysca.scanUpToString("0 @")
      else {
        print("failed reading up to next record")
        return
      }
      switch xRef[xRef.startIndex] {
      case "F":
        famDict[xRef] = textContent
      case "I":
        indivDict[xRef] = textContent
      case "S":
        sourceDict[xRef] = textContent
      default:
        otherDict[xRef] = textContent
      }
      if !mysca.isAtEnd {
        guard let _ = mysca.scanString("0 @"),
              let tempXRef = mysca.scanUpToString("@"),
              let _ = mysca.scanString("@")
        else {
          print("failed reading next xRef")
          return
        }
        xRef = tempXRef
      }
    }
    sources = sourceDict
    others = otherDict
// Process the individual name, rearrange with
// surname first, save surname in its own dict.
    var surnameDict: [String: String] = [:]
    var localIndividuals: [Individual] = []
    for (indivXRef, indivContent) in indivDict {
      var theName: String?
      if let nameValue = indivContent.restOfLineFrom("1 NAME ") {
        let parts = nameValue.split(separator: "/" )
        switch parts.count {
        case 1:
          let processed = String(parts[0])
          if processed.count == nameValue.count {  // had no slashes, so no surname
            theName = "? " + processed
            surnameDict[xRef] = "?"
          }
          else {
            theName = processed + " ?"  // surname only
            surnameDict[indivXRef] = String(processed)
          }
        case 2:
          let given = String(parts[0])
          let surname = String(parts[1])
          theName = surname + " " + given
          surnameDict[indivXRef] = surname
        case 3:
          let given = String(parts[0])
          let surname = String(parts[1])
          let suffix = String(parts[2])
          theName = surname + " " + given + suffix
          surnameDict[indivXRef] = surname
        default:
          break
        }
      }
      localIndividuals.append(Individual(id: indivXRef, name: theName ?? "?", textContent: indivContent))
    }
    individuals = localIndividuals
// Process the individual links for family
// spouse surnames.
    var localFamilies: [Family] = []
    for (famXRef, famContent) in famDict {
      var husband: String? = "noTAG"
      if let husbValue = famContent.restOfLineFrom("1 HUSB ") {
        let parts = husbValue.split(separator: "@" )
        if parts.count > 0 {
          let localXRef = String(parts[0])
          husband = surnameDict[localXRef] ?? "noINDI"
        }
      }
      var wife: String? = "noTAG"
      if let wifeValue = famContent.restOfLineFrom("1 WIFE ") {
        let parts = wifeValue.split(separator: "@" )
        if parts.count > 0 {
          let localXRef = String(parts[0])
          wife = surnameDict[localXRef] ?? "noINDI"
         }
      }
      localFamilies.append(Family(id: famXRef, husb: husband ?? "?", wife: wife ?? "?", textContent: famContent))
    }
    families = localFamilies
  }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
