import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TabView {
                HomeView()
                    .tabItem {
                        Image(systemName: "house")
                        Text("Home")
                    }

                TemplatesView()
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("Templates")
                    }

                WorkoutMenuView()
                    .tabItem {
                        Image(systemName: "play.circle")
                        Text("Workout")
                    }

                HistoryView()
                    .tabItem {
                        Image(systemName: "clock")
                        Text("History")
                    }
            }
        }
    }
}


