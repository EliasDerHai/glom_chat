import { Session } from "../types";
import { useState } from "react";
import {
  IonButton,
  IonInput,
  IonItem,
  IonLabel,
  IonSegment,
  IonSegmentButton,
} from "@ionic/react";

type Mode = "login" | "signup";

const LoginPage = ({ onLogin }: { onLogin: (s: Session) => void }) => {
  const [mode, setMode] = useState<Mode>("login");

  return (
    <form
      className="flex flex-col gap-5 p-8 w-full h-full bg-white"
      onSubmit={(e) => {
        e.preventDefault();
        // TODO: submit
      }}
    >
      {/* Toggle buttons */}
      <IonSegment
        value={mode}
        onIonChange={(e) => setMode(e.detail.value as Mode)}
      >
        <IonSegmentButton value="login">
          <IonLabel>Login</IonLabel>
        </IonSegmentButton>
        <IonSegmentButton value="signup">
          <IonLabel>Signup</IonLabel>
        </IonSegmentButton>
      </IonSegment>

      {/* Title */}
      <h1 className="text-xl font-bold text-blue-600">
        {mode === "login" ? "Login" : "Create account"}
      </h1>

      {/* Fields */}
      {mode === "login" ? (
        <div>
          <IonItem>
            <IonLabel position="stacked">Username</IonLabel>
            <IonInput type="text" name="username" placeholder="your_username" />
          </IonItem>
          <IonItem>
            <IonLabel position="stacked">Password</IonLabel>
            <IonInput type="password" name="password" placeholder="••••••••" />
          </IonItem>
        </div>
      ) : (
        <div>
          <IonItem>
            <IonLabel position="stacked">Username</IonLabel>
            <IonInput type="text" name="username" placeholder="your_username" />
          </IonItem>
          <IonItem>
            <IonLabel position="stacked">Email</IonLabel>
            <IonInput type="email" name="email" placeholder="you@example.com" />
          </IonItem>
          <IonItem>
            <IonLabel position="stacked">Password</IonLabel>
            <IonInput type="password" name="password" placeholder="••••••••" />
          </IonItem>
          <IonItem>
            <IonLabel position="stacked">Confirm password</IonLabel>
            <IonInput
              type="password"
              name="password_confirm"
              placeholder="••••••••"
            />
          </IonItem>
        </div>
      )}

      {/* Submit button */}
      <IonButton expand="block" type="submit" className="mt-2">
        {mode === "login" ? "Log in" : "Create account"}
      </IonButton>
    </form>
  );
};

export default LoginPage;
