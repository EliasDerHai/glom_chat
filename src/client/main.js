// Entry point for Vite + Gleam application
import { main } from './src/app.gleam';
import './src/app.css'; // Import your styles if you have them

// Initialize the Gleam application when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  console.log('🔥 Vite + Gleam application starting...');

  // Find the root element (adjust selector if needed)
  const appElement = document.getElementById('app') || document.body;

  // Start your Gleam Lustre application
  try {
    const dispatch = main();
    console.log('✅ Gleam application initialized successfully');
  } catch (error) {
    console.error('❌ Failed to initialize Gleam application:', error);
  }
});