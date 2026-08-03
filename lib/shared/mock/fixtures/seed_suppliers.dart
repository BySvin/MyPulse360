import '../../../features/pharmacist/domain/entities/supplier.dart';

List<Supplier> seedSuppliers() => const [
      Supplier(
        id: 'sup-mediwholesale',
        name: 'MediWholesale Distributors',
        contactName: 'Karen Ruiz',
        phone: '+1 555-0210',
        email: 'orders@mediwholesale.example',
      ),
      Supplier(
        id: 'sup-pharmalink',
        name: 'PharmaLink Supply Co.',
        contactName: 'Tom Baxter',
        phone: '+1 555-0233',
        email: 'sales@pharmalink.example',
      ),
    ];
