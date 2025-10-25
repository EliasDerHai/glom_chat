import {
  IonContent,
  IonHeader,
  IonPage,
  IonTitle,
  IonToolbar,
} from "@ionic/react";
import * as endpoints from "@shared/shared/endpoints.mjs";

const Main = () => {
  const me = endpoints.me();

  return (
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <IonTitle>Glom chat</IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent fullscreen>
        <span>...</span>
      </IonContent>
    </IonPage>
  );
};
export default Main;
