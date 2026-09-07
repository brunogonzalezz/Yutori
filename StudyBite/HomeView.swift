import SwiftUI

struct HomeView: View {
    
    @State var showSettings = false
    
    var body: some View {
        
        VStack(spacing: 0) {
            HStack {
                Button {
                    showSettings = true
                } label: {
                    Image("perfilePic")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                }
                .buttonStyle(.plain)
                
                Text("Hi, Bruno!")
                    .font(.system(size: 20))
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.horizontal, 25)
            .padding(.bottom, -25)
            
            VStack(spacing: 20) {
                
                Image("bowl")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 330, height: 330)
                
                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.25))
                                .frame(height: 7)
                            
                            Capsule()
                                .fill(Color.black)
                                .frame(
                                    width: geometry.size.width * 0.65,
                                    height: 7
                                )
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black)
                                    .frame(width: 28, height: 28)
                                    .rotationEffect(.degrees(45))
                                
                                Text("4")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .frame(height: 15)
                    
                    Text("41 min remaining")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 60)
                .offset(y: -45)
            }
            .padding(.top, 5)
            
            VStack(alignment: .leading, spacing: 14) {
                
                Spacer()
                    .frame(height: 5)
                
                Text("Last sessions")
                    .font(.system(size: 24, weight: .bold))
                
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.pastelBlue)
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "percent")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Maths")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Sequences and limits")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("1h 19m")
                        .font(.system(size: 17, weight: .medium))
                }
                
                Divider()
                
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.pastelGreen)
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "atom")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Science")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Thermodynamics")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("2h 22m")
                        .font(.system(size: 17, weight: .medium))
                }
                
                Divider()
                
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.pastelOrange)
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "book")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("History")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("History of Spain")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("34m")
                        .font(.system(size: 17, weight: .medium))
                }
            }
            .padding(.horizontal, 28)
            .offset(y: -25)
            
            Spacer()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

#Preview {
    HomeView()
}
