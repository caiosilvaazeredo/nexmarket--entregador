/**
 * Shared data model. These types mirror the Firestore schema used by the
 * Nexmarket (loja) app so both apps read/write the SAME database.
 *
 * Collections:
 *   /drivers/{uid}                              -> DriverProfile
 *   /drivers/{uid}/payouts/{payoutId}           -> Payout
 *   /supermarkets/{smId}                        -> Supermarket (read-only here)
 *   /supermarkets/{smId}/orders/{orderId}       -> Order (+ delivery fields)
 *   /supermarkets/{smId}/orders/{id}/messages   -> ChatMessage
 *   /supermarkets/{smId}/deliveryConfig/main    -> DeliveryConfig (read-only here)
 */

export type VehicleType = 'moto' | 'carro' | 'bike' | 'van';

export interface Vehicle {
  type: VehicleType;
  plate: string;
  model: string;
  color?: string;
  year?: string;
}

export type DocStatus = 'pending' | 'approved' | 'rejected';

export interface DriverDocuments {
  cnhUrl?: string;
  vehicleDocUrl?: string;
  profilePhotoUrl?: string;
  status: DocStatus;
}

export interface BankInfo {
  holderName?: string;
  cpf?: string;
  bankName?: string;
  agency?: string;
  account?: string;
  pixKey?: string;
}

export interface DriverPreferences {
  soundAlerts: boolean;
  darkMode: boolean;
  navApp: 'google' | 'waze';
}

export interface GeoPoint {
  lat: number;
  lng: number;
  updatedAt?: any;
}

export type DriverStatus = 'online' | 'offline' | 'on_delivery';

export interface DriverProfile {
  uid: string;
  name: string;
  email: string;
  phone: string;
  photoUrl?: string;
  status: DriverStatus;
  vehicle: Vehicle;
  documents: DriverDocuments;
  bank: BankInfo;
  preferences: DriverPreferences;
  location?: GeoPoint | null;
  rating: number;
  totalDeliveries: number;
  balance: number;
  createdAt?: any;
  updatedAt?: any;
}

export interface OrderItem {
  productId: string;
  name: string;
  quantity: number;
  price: number;
  separated?: boolean;
  missing?: boolean;
  substituted?: boolean;
  substituteName?: string;
  substitutePrice?: number;
}

export interface DeliveryAddress {
  street?: string;
  number?: string;
  complement?: string;
  neighborhood?: string;
  city?: string;
  reference?: string;
  lat?: number;
  lng?: number;
}

export interface ProofOfDelivery {
  signatureUrl?: string;
  photoUrl?: string;
  note?: string;
  receivedBy?: string;
}

export type ProblemType =
  | 'address_not_found'
  | 'customer_absent'
  | 'damaged_package'
  | 'other';

export interface ProblemReport {
  type: ProblemType;
  note?: string;
  reportedAt?: any;
}

/** Store-facing order status (existing in loja). */
export type OrderStatus =
  | 'pending'
  | 'picking'
  | 'waiting_substitution'
  | 'ready'
  | 'delivered'
  | 'cancelled';

/** Granular delivery sub-status owned by the driver app. */
export type DeliveryStatus =
  | 'awaiting_driver'
  | 'assigned'
  | 'going_to_store'
  | 'arrived_store'
  | 'picked_up'
  | 'going_to_customer'
  | 'delivered'
  | 'problem';

export interface Order {
  id: string;
  supermarketId: string;
  customerId: string;
  status: OrderStatus;
  items: OrderItem[];
  total: number;

  // Delivery fields (added by checkout / driver app)
  deliveryStatus?: DeliveryStatus;
  deliveryAddress?: DeliveryAddress;
  customerName?: string;
  customerPhone?: string;
  deliveryFee?: number;

  driverId?: string;
  driverName?: string;
  driverLocation?: GeoPoint | null;
  driverEarnings?: number;

  acceptedAt?: any;
  pickedUpAt?: any;
  deliveredAt?: any;
  proofOfDelivery?: ProofOfDelivery;
  problemReport?: ProblemReport | null;

  rating?: number;
  ratingComment?: string;

  createdAt?: any;
  updatedAt?: any;

  // Joined client-side only
  storeName?: string;
  storeLocation?: GeoPoint | null;
  storeAddress?: string;
}

export type PayoutStatus = 'requested' | 'processing' | 'paid' | 'rejected';

export interface Payout {
  id: string;
  amount: number;
  status: PayoutStatus;
  method: string;
  destination: string;
  createdAt?: any;
  updatedAt?: any;
}

export type ChatRole = 'driver' | 'customer' | 'store' | 'support';

export interface ChatMessage {
  id: string;
  text: string;
  senderId: string;
  senderRole: ChatRole;
  createdAt?: any;
}
