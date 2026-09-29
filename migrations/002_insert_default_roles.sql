-- Insert default roles required by user_create() function
-- Run this against your Neon database if you get "Default role User not found"
INSERT INTO roles (role_name) VALUES ('User'), ('Admin') ON CONFLICT (role_name) DO NOTHING;
