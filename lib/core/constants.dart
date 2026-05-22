class Rol {
  static const int superadmin       = 1;
  static const int adminEmpresa     = 2;
  static const int encargado        = 3;
  static const int capataz          = 4;
  static const int liquidador       = 5;
  static const int encargadoAlmacen = 6;
}

const String kBaseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://control-almacen-n56o.onrender.com/api/',
);
