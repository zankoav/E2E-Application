@IsTest
global class TestUppercaseMappingTransform implements MappingTransform {
    global Object transform(MappingTransformContext context) {
        return context.sourceValue == null ? null : String.valueOf(context.sourceValue).toUpperCase();
    }
}
