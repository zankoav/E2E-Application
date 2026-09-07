global class DefaultMappingTransform implements MappingTransform {
    global Object transform(MappingTransformContext context) {
        return context == null ? null : context.sourceValue;
    }
}
