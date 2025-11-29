import {
  IonContent,
  IonHeader,
  IonPage,
  IonSpinner,
  IonTitle,
  IonToolbar,
} from "@ionic/react";
import { useState, useEffect } from "react";
import ChatPage from "./ChatPage";
import LoginPage from "./LoginPage";
import { Session } from "../types";

type LoginState = Session | "logged-out" | "checking-session";

const MainPage = () => {
  const [session, setSession] = useState<LoginState>("checking-session");

  useEffect(() => {
    fetch("http://localhost:8000/auth/me")
      .then((res) => (res.ok ? res.json() : "logged-out"))
      .then(setSession);
  }, []);

  function content() {
    if (session === "checking-session") {
      return (
        <div className="flex h-full w-full items-center justify-center flex-col">
          <IonSpinner />
          <p>... checking login ...</p>
        </div>
      );
    } else if (session === "logged-out") {
      return <LoginPage onLogin={(s: Session) => setSession(s)} />;
    } else {
      return (
        <ChatPage session={session} onLogout={() => setSession("logged-out")} />
      );
    }
  }

  return (
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <IonTitle>Glom chat</IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent fullscreen>{content()}</IonContent>
    </IonPage>
  );
};
export default MainPage;
