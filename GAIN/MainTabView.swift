import SwiftUI

struct MainTabView: View {
    var body: some View {
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

            BodyMapView()
                .tabItem {
                    Image(systemName: "figure.arms.open")
                    Text("Body")
                }

            HistoryView()
                .tabItem {
                    Image(systemName: "clock")
                    Text("History")
                }
        }
    }
}


