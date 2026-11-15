//
//  SupabaseManager.swift
//  StudyReward
//
//  Created by jaya on 07/11/26.
//

import Foundation
import Supabase

final class SupabaseManager {

    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://knwkjkhdhcszoghvfzqq.supabase.co")!,
            supabaseKey: "sb_publishable_XyicIgsdxQP_quKL5blDIg_TeTXyeLi"
        )
    }
}
