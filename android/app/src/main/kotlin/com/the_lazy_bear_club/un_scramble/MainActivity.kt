package com.the_lazy_bear_club.un_scramble

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

// Edge-to-edge on every Android version, not only 15+ where it is forced.
// Flutter's SafeArea / MediaQuery padding handles the system bar insets.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
